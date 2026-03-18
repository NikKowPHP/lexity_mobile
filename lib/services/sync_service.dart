import 'dart:convert';
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
    if (_ref.read(isSyncingProvider) && !force) {
      _logger.info('SyncService: Sync already in progress, skipping...');
      return;
    }

    final isOnline = _ref.read(connectivityProvider);
    if (!isOnline) {
      _logger.info('SyncService: Offline, skipping sync...');
      return;
    }

    _ref.read(isSyncingProvider.notifier).state = true;
    _logger.info('SyncService: Starting sync${force ? " (FORCED)" : ""}...');

    try {
      final mutations = await _syncRepo.getPendingMutations();
      _logger.info('SyncService: Found ${mutations.length} pending mutations');

      for (final mutation in mutations) {
        if (!_ref.read(connectivityProvider)) {
          _logger.warning('SyncService: Lost network connection, pausing sync');
          break;
        }

        final retryCount = mutation['retry_count'] as int? ?? 0;

        if (retryCount > 0 && !force) {
          final delay = _calculateBackoff(retryCount);
          _logger.info(
            'SyncService: Applying backoff of ${delay.inSeconds}s for mutation ${mutation['id']}',
          );
          await Future.delayed(delay);
        } else if (retryCount > 0 && force) {
          _logger.info(
            'SyncService: Forced sync, bypassing backoff for mutation ${mutation['id']}',
          );
        }

        final success = await _processMutation(mutation);
        if (success) {
          await _syncRepo.removeMutation(mutation['id'] as int);
          _logger.info(
            'SyncService: Successfully synced mutation ${mutation['id']}',
          );
        } else {
          await _syncRepo.incrementRetryCount(mutation['id'] as int);
          _logger.warning(
            'SyncService: Mutation ${mutation['id']} failed. Stopping queue processing to prevent infinite hammering.',
          );
          break;
        }
      }

      _lastSyncTime = DateTime.now();
      _ref.read(lastSyncTimeProvider.notifier).state = _lastSyncTime;
      _logger.info('SyncService: Sync completed at $_lastSyncTime');
    } catch (e, st) {
      _logger.error('SyncService: Sync failed', e, st);
    } finally {
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
