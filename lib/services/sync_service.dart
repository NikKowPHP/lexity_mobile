import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import '../services/token_service.dart';
import '../utils/constants.dart';
import '../services/logger_service.dart';

class SyncService {
  final SyncRepository _syncRepo;
  final Ref _ref;
  final LoggerService _logger;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  SyncService(this._syncRepo, this._ref, this._logger);

  void startListening() {
    _ref.listen<bool>(connectivityProvider, (previous, next) {
      if (next && !_isSyncing) {
        _logger.info('SyncService: Network became available, starting sync...');
        syncPendingMutations();
      }
    });
  }

  Future<void> syncPendingMutations() async {
    if (_isSyncing) {
      _logger.info('SyncService: Sync already in progress, skipping...');
      return;
    }

    final isOnline = _ref.read(connectivityProvider);
    if (!isOnline) {
      _logger.info('SyncService: Offline, skipping sync...');
      return;
    }

    _isSyncing = true;
    _logger.info('SyncService: Starting sync...');

    try {
      final mutations = await _syncRepo.getPendingMutations();
      _logger.info('SyncService: Found ${mutations.length} pending mutations');

      for (final mutation in mutations) {
        if (!_ref.read(connectivityProvider)) {
          _logger.warning('SyncService: Lost network connection, pausing sync');
          break;
        }

        final retryCount = mutation['retry_count'] as int? ?? 0;

        if (retryCount > 0) {
          final delay = _calculateBackoff(retryCount);
          _logger.info(
            'SyncService: Applying backoff of ${delay.inSeconds}s for mutation ${mutation['id']}',
          );
          await Future.delayed(delay);
        }

        final success = await _processMutation(mutation);
        if (success) {
          await _syncRepo.removeMutation(mutation['id'] as int);
          _logger.info(
            'SyncService: Successfully synced mutation ${mutation['id']}',
          );
        } else {
          // CRITICAL FIX: If a mutation fails, increment retry and STOP the loop.
          // Do not attempt the rest of the queue in this cycle.
          await _syncRepo.incrementRetryCount(mutation['id'] as int);
          _logger.warning(
            'SyncService: Mutation ${mutation['id']} failed. Stopping queue processing to prevent infinite hammering.',
          );
          break;
        }
      }

      _lastSyncTime = DateTime.now();
      _logger.info('SyncService: Sync completed at $_lastSyncTime');
    } catch (e, st) {
      _logger.error('SyncService: Sync failed', e, st);
    } finally {
      _isSyncing = false;
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
    final tokenService = _ref.read(tokenServiceProvider(TokenType.auth));
    final token = await tokenService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (action == 'update_progress') {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/books/$bookId/progress'),
        headers: headers,
        body: jsonEncode({
          'currentCfi': payload['currentCfi'],
          'progressPct': payload['progressPct'],
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } else if (action == 'delete') {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/books/$bookId'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    }

    return true;
  }

  Future<bool> _syncJournalMutation(
    String action,
    String journalId,
    Map<String, dynamic> payload,
  ) async {
    final tokenService = _ref.read(tokenServiceProvider(TokenType.auth));
    final token = await tokenService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (action == 'create') {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/journal'),
        headers: headers,
        body: jsonEncode({
          'id': journalId,
          'title': payload['title'],
          'content': payload['content'],
          'targetLanguage': payload['targetLanguage'],
          'moduleId': payload['moduleId'],
          'mode': payload['mode'],
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } else if (action == 'analyze') {
      _logger.info('SyncService: Triggering analysis for journal $journalId');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/analyze'),
        headers: headers,
        body: jsonEncode({'journalId': journalId}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    }

    return true;
  }

  Future<bool> _syncSrsMutation(
    String action,
    String itemId,
    Map<String, dynamic> payload,
  ) async {
    final tokenService = _ref.read(tokenServiceProvider(TokenType.auth));
    final token = await tokenService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (action == 'review') {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/srs/$itemId/review'),
        headers: headers,
        body: jsonEncode({'nextReviewDate': payload['nextReviewDate']}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    }

    return true;
  }

  Future<bool> _syncVocabMutation(
    String action,
    String word,
    Map<String, dynamic> payload,
  ) async {
    final tokenService = _ref.read(tokenServiceProvider(TokenType.auth));
    final token = await tokenService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (action == 'update') {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/vocabulary'),
        headers: headers,
        body: jsonEncode({
          'word': word,
          'targetLanguage': payload['targetLanguage'],
          'status': payload['status'],
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    }

    return true;
  }

  DateTime? get lastSyncTime => _lastSyncTime;
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final service = SyncService(syncRepo, ref, logger);
  service.startListening();
  return service;
});

final syncQueueCountProvider = FutureProvider<int>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return await syncRepo.getPendingCount();
});

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);
