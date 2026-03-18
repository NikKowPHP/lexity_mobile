import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import '../services/logger_service.dart';
import '../providers/user_provider.dart';
import '../network/api_client.dart';

class SyncService {
  final SyncRepository _syncRepo;
  final ApiClient _client;
  final Ref _ref;
  final LoggerService _logger;
  DateTime? _lastSyncTime;
  bool _syncLock = false;

  SyncService(this._syncRepo, this._client, this._ref, this._logger);

  void startListening() {
    _ref.listen<bool>(connectivityProvider, (previous, next) {
      if (next && !_ref.read(isSyncingProvider)) {
        _logger.info('SyncService: Network became available, starting sync...');
        syncPendingMutations();
      }
    });
  }

  Future<void> syncPendingMutations({bool force = false}) async {
    if (_syncLock && !force) {
      _logger.info('SyncService: Sync already in progress (lock), skipping...');
      return;
    }

    final isOnline = _ref.read(connectivityProvider);
    if (!isOnline) {
      _logger.info('SyncService: Offline, skipping sync...');
      return;
    }

    _syncLock = true;
    _ref.read(isSyncingProvider.notifier).state = true;
    _logger.info('SyncService: Starting sync${force ? " (FORCED)" : ""}...');

    List<int> successfullyProcessedIds = [];

    try {
      // Compact the queue before processing to eliminate redundant mutations
      await _syncRepo.compactSyncQueue();
      _logger.info('SyncService: Queue compacted');

      final mutations = await _syncRepo.getPendingMutations();
      _logger.info('SyncService: Found ${mutations.length} pending mutations after compaction');

      if (mutations.isEmpty) {
        return;
      }

      // Group mutations by entity_type, action, and relevant payload fields
      final groups = _groupMutations(mutations);
      _logger.info('SyncService: Grouped into ${groups.length} batches');

      bool stopProcessing = false;

      // Process each group in order
      for (final groupEntry in groups.entries) {
        if (stopProcessing) break;

        final key = groupEntry.key;
        final groupMutations = groupEntry.value;
        final entityType = key.entityType;
        final action = key.action;

        _logger.info('SyncService: Processing group $entityType:$action with ${groupMutations.length} items');

        // Determine if this group should be batched
        final shouldBatch = (entityType == 'vocabulary' && action == 'update') ||
                           (entityType == 'srs' && action == 'review');

        if (shouldBatch) {
          // Try batch processing
          final batchSuccess = await _processBatch(entityType, action, groupMutations);
          if (batchSuccess) {
            final batchIds = groupMutations.map((m) => m['id'] as int).toList();
            successfullyProcessedIds.addAll(batchIds);
            _logger.info('SyncService: Batch succeeded for $entityType:$action, processed ${batchIds.length} items');
          } else {
            _logger.warning('SyncService: Batch failed for $entityType:$action, falling back to individual processing');
            // Fallback: process each mutation individually
            for (final mutation in groupMutations) {
              if (!_ref.read(connectivityProvider)) {
                _logger.warning('SyncService: Lost network connection, pausing sync');
                stopProcessing = true;
                break;
              }

              final retryCount = mutation['retry_count'] as int? ?? 0;
              if (retryCount > 0 && !force) {
                final delay = _calculateBackoff(retryCount);
                _logger.info('SyncService: Applying backoff of ${delay.inSeconds}s for mutation ${mutation['id']}');
                await Future.delayed(delay);
              }

              final success = await _processMutation(mutation);
              if (success) {
                successfullyProcessedIds.add(mutation['id'] as int);
              } else {
                await _syncRepo.incrementRetryCount(mutation['id'] as int);
                _logger.warning('SyncService: Individual mutation ${mutation['id']} failed after batch fallback. Stopping queue processing.');
                stopProcessing = true;
                break;
              }
            }
          }
        } else {
          // Non-batchable: process individually
          for (final mutation in groupMutations) {
            if (!_ref.read(connectivityProvider)) {
              _logger.warning('SyncService: Lost network connection, pausing sync');
              stopProcessing = true;
              break;
            }

            final retryCount = mutation['retry_count'] as int? ?? 0;
            if (retryCount > 0 && !force) {
              final delay = _calculateBackoff(retryCount);
              _logger.info('SyncService: Applying backoff of ${delay.inSeconds}s for mutation ${mutation['id']}');
              await Future.delayed(delay);
            }

            final success = await _processMutation(mutation);
            if (success) {
              successfullyProcessedIds.add(mutation['id'] as int);
            } else {
              await _syncRepo.incrementRetryCount(mutation['id'] as int);
              _logger.warning('SyncService: Mutation ${mutation['id']} failed. Stopping queue processing to prevent infinite hammering.');
              stopProcessing = true;
              break;
            }
          }
        }
      }

      // Bulk delete processed mutations
      if (successfullyProcessedIds.isNotEmpty) {
        await _syncRepo.removeMutations(successfullyProcessedIds);
        _logger.info('SyncService: Removed ${successfullyProcessedIds.length} processed mutations from queue');
      }

      _lastSyncTime = DateTime.now();
      _ref.read(lastSyncTimeProvider.notifier).state = _lastSyncTime;
      _logger.info('SyncService: Sync completed at $_lastSyncTime');
    } catch (e, st) {
      _logger.error('SyncService: Sync failed', e, st);
    } finally {
      _syncLock = false;
      _ref.read(isSyncingProvider.notifier).state = false;
      _ref.invalidate(syncQueueCountProvider);
    }
  }

  Duration _calculateBackoff(int retryCount) {
    final baseSeconds = 5;
    final maxSeconds = 300;
    final seconds = (baseSeconds * (1 << retryCount)).clamp(1, maxSeconds);
    return Duration(seconds: seconds);
  }

  // Group mutations by entity_type, action, and payload characteristics
  Map<_GroupKey, List<Map<String, dynamic>>> _groupMutations(List<Map<String, dynamic>> mutations) {
    final groups = <_GroupKey, List<Map<String, dynamic>>>{};
    for (final mutation in mutations) {
      final entityType = mutation['entity_type'] as String;
      final action = mutation['action'] as String;
      String? subKey;
      
      // For vocabulary updates, group by status to ensure uniform batch payloads
      if (entityType == 'vocabulary' && action == 'update') {
        final payload = jsonDecode(mutation['payload_json'] as String) as Map<String, dynamic>;
        subKey = payload['status'] as String?;
      }
      
      final key = _GroupKey(entityType, action, subKey);
      groups.putIfAbsent(key, () => []).add(mutation);
    }
    return groups;
  }

  // Process a batch of mutations with a single API call
  Future<bool> _processBatch(String entityType, String action, List<Map<String, dynamic>> mutations) async {
    _logger.info('Batch Sync: $entityType:$action with ${mutations.length} items');
    try {
      switch (entityType) {
        case 'vocabulary':
          if (action == 'update') {
            // All mutations in this group have the same status (due to grouping)
            final firstPayload = jsonDecode(mutations.first['payload_json'] as String) as Map<String, dynamic>;
            final status = firstPayload['status'] as String;
            final targetLanguage = firstPayload['targetLanguage'] as String? ?? _ref.read(activeLanguageProvider);
            final words = mutations.map((m) => m['entity_id'] as String).toList();
            
            // Extended timeout for batch requests
            final options = Options(
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
            );
            
            final response = await _client.post(
              '/api/vocabulary',
              data: {
                'words': words,
                'targetLanguage': targetLanguage,
                'status': status,
              },
              options: options,
            );
            final statusCode = response.statusCode;
            return statusCode != null && statusCode >= 200 && statusCode < 300;
          }
          return true; // other actions not batchable
          
        case 'srs':
          if (action == 'review') {
            final reviews = mutations.map((m) {
              final payload = jsonDecode(m['payload_json'] as String) as Map<String, dynamic>;
              return {
                'id': m['entity_id'],
                'date': payload['nextReviewDate'],
              };
            }).toList();
            
            // Extended timeout for batch requests
            final options = Options(
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
            );
            
            final response = await _client.post(
              '/api/srs/batch-review',
              data: {'reviews': reviews},
              options: options,
            );
            final statusCode = response.statusCode;
            return statusCode != null && statusCode >= 200 && statusCode < 300;
          }
          return true;
          
        default:
          // For other types, treat as success to avoid infinite loops
          return true;
      }
    } catch (e) {
      _logger.error('SyncService: Batch processing error for $entityType:$action', e);
      return false;
    }
  }

  Future<bool> _processMutation(Map<String, dynamic> mutation) async {
    final entityType = mutation['entity_type'] as String;
    final action = mutation['action'] as String;
    final entityId = mutation['entity_id'] as String;
    final payload =
        jsonDecode(mutation['payload_json'] as String) as Map<String, dynamic>;

    try {
      _logger.info('Syncing $entityType:$action for ID: $entityId');

      switch (entityType) {
        case 'book':
          return await _syncBookMutation(action, entityId, payload);
        case 'journal':
          return await _syncJournalMutation(action, entityId, payload);
        case 'srs':
          return await _syncSrsMutation(action, entityId, payload);
        case 'vocabulary':
          return await _syncVocabMutation(action, entityId, payload);
        default:
          _logger.warning('SyncService: Unknown entity type: $entityType');
          return true;
      }
    } catch (e) {
      _logger.error('SyncService: Error processing mutation', e);
      return false;
    }
  }

  Future<bool> _syncBookMutation(
    String action,
    String bookId,
    Map<String, dynamic> payload,
  ) async {
    if (action == 'update_progress') {
      final response = await _client.put(
        '/api/books/$bookId/progress',
        data: {
          'currentCfi': payload['currentCfi'],
          'progressPct': payload['progressPct'],
        },
      );
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    } else if (action == 'delete') {
      final response = await _client.delete('/api/books/$bookId');
      final status = response.statusCode;
      return status != null && (status == 200 || status == 204);
    }

    return true;
  }

  Future<bool> _syncJournalMutation(
    String action,
    String journalId,
    Map<String, dynamic> payload,
  ) async {
    if (action == 'create') {
      final response = await _client.post(
        '/api/journal',
        data: {
          'id': journalId,
          'title': payload['title'],
          'content': payload['content'],
          'targetLanguage': payload['targetLanguage'],
          'moduleId': payload['moduleId'],
          'mode': payload['mode'],
        },
      );
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    } else if (action == 'analyze') {
      _logger.info('SyncService: Triggering analysis for journal $journalId');
      final response = await _client.post(
        '/api/analyze',
        data: {'journalId': journalId},
      );
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    }

    return true;
  }

  Future<bool> _syncSrsMutation(
    String action,
    String itemId,
    Map<String, dynamic> payload,
  ) async {
    if (action == 'review') {
      final response = await _client.put(
        '/api/srs/$itemId/review',
        data: {'nextReviewDate': payload['nextReviewDate']},
      );
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    }

    return true;
  }

  Future<bool> _syncVocabMutation(
    String action,
    String word,
    Map<String, dynamic> payload,
  ) async {
    final targetLanguage =
        payload['targetLanguage'] ?? _ref.read(activeLanguageProvider);

    if (action == 'batch_update') {
      final words = payload['words'] as List<dynamic>;
      final statusStr = payload['status'] as String;

      final response = await _client.post(
        '/api/vocabulary',
        data: {
          'words': words.map((w) => w.toString()).toList(),
          'targetLanguage': targetLanguage,
          'status': statusStr.toUpperCase(),
        },
      );
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    } else if (action == 'update') {
      final statusStr = payload['status'] as String;

      final response = await _client.put(
        '/api/vocabulary',
        data: {
          'word': word,
          'targetLanguage': targetLanguage,
          'status': statusStr.toUpperCase(),
        },
      );
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    }

    return true;
  }

  DateTime? get lastSyncTime => _lastSyncTime;
}

class _GroupKey {
  final String entityType;
  final String action;
  final String? subKey;

  _GroupKey(this.entityType, this.action, [this.subKey]);

  @override
  bool operator ==(Object other) =>
      other is _GroupKey &&
      other.entityType == entityType &&
      other.action == action &&
      other.subKey == subKey;

  @override
  int get hashCode => entityType.hashCode ^ action.hashCode ^ (subKey?.hashCode ?? 0);
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final client = ref.watch(apiClientProvider);
  final service = SyncService(syncRepo, client, ref, logger);
  service.startListening();
  return service;
});

final syncQueueCountProvider = FutureProvider<int>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return await syncRepo.getPendingCount();
});

class LastSyncTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
}

final lastSyncTimeProvider =
    NotifierProvider<LastSyncTimeNotifier, DateTime?>(() => LastSyncTimeNotifier());

class IsSyncingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final isSyncingProvider =
    NotifierProvider<IsSyncingNotifier, bool>(() => IsSyncingNotifier());
