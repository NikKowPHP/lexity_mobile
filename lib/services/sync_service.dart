import 'dart:convert';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../data/datasources/remote/sync_remote_datasource.dart';
import '../providers/connectivity_provider.dart';
import '../services/logger_service.dart';
import '../network/api_client.dart';

class SyncService {
  final SyncRepository _syncRepo;
  final ApiClient _client;
  final Ref _ref;
  final LoggerService _logger;
  final AppDatabase _db;
  final SyncRemoteDataSource _syncRemote;
  DateTime? _lastSyncTime;
  bool _syncLock = false;

  static const int _batchSize = 50;
  static const int _maxConcurrentBatches = 3;
  static const int _maxRetries = 5;

  SyncService(
    this._syncRepo,
    this._client,
    this._ref,
    this._logger,
    this._db,
    this._syncRemote,
  );

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

    try {
      await _syncRepo.compactSyncQueue();
      _logger.info('SyncService: Queue compacted');

      final totalCount = await _syncRepo.getPendingCount();
      _logger.info(
        'SyncService: Found $totalCount pending mutations after compaction',
      );

      if (totalCount == 0) {
        return;
      }

      final batchCount = (totalCount / _batchSize).ceil();
      final batches = <Future<void>>[];

      for (int i = 0; i < batchCount && i < _maxConcurrentBatches; i++) {
        final offset = i * _batchSize;
        batches.add(_processBulkBatch(offset));
      }

      await Future.wait(batches);

      final remainingCount = await _syncRepo.getPendingCount();
      if (remainingCount > 0 && _ref.read(connectivityProvider)) {
        _logger.info(
          'SyncService: $remainingCount items remaining, scheduling next batch',
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          syncPendingMutations();
        });
        return;
      }

      _lastSyncTime = DateTime.now();
      _ref.read(lastSyncTimeProvider.notifier).state = _lastSyncTime;
      _logger.info('SyncService: Sync completed at $_lastSyncTime');
    } on DioException catch (e) {
      _logger.error('SyncService: Network error during bulk sync', e);
    } catch (e, st) {
      _logger.error('SyncService: Sync failed', e, st);
    } finally {
      _syncLock = false;
      _ref.read(isSyncingProvider.notifier).state = false;
      _ref.invalidate(syncQueueCountProvider);
    }
  }

  Future<void> _processBulkBatch(int offset) async {
    _logger.info('SyncService: Processing bulk batch at offset $offset');

    final mutations = await _syncRepo.getPendingMutations(
      limit: _batchSize,
      offset: offset,
    );
    if (mutations.isEmpty) {
      return;
    }

    _logger.info(
      'SyncService: Fetched ${mutations.length} $mutations mutations for bulk processing',
    );

    final ops = await Isolate.run(() => _prepareBulkPayload(mutations));

    final options = Options(
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    );

    final response = await _client.post(
      '/api/sync/bulk',
      data: {'ops': ops},
      options: options,
    );

    await _handleBulkResponse(response, mutations);
  }

  static List<Map<String, dynamic>> _prepareBulkPayload(
    List<Map<String, dynamic>> mutations,
  ) {
    return mutations.map((item) {
      final timestampMs = int.parse(item['created_at'].toString());
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        timestampMs,
      ).toUtc().toIso8601String();
      return {
        'cid': item['id'].toString(),
        'type': item['entity_type'],
        'action': item['action'],
        'payload': jsonDecode(item['payload_json'] as String),
        'timestamp': timestamp,
      };
    }).toList();
  }

  Future<void> _handleBulkResponse(
    Response response,
    List<Map<String, dynamic>> mutations,
  ) async {
    final results = response.data['results'] as List<dynamic>;
    final successIds = <int>[];
    final failedIds = <MapEntry<int, String?>>[];

    for (final result in results) {
      final cid = int.parse(result['cid'].toString());
      final status = result['status'] as int;
      final error = result['error'] as String?;

      if (status >= 200 && status < 300) {
        successIds.add(cid);
      } else {
        failedIds.add(MapEntry(cid, error));
      }
    }

    if (successIds.isNotEmpty) {
      await _syncRepo.removeMutations(successIds);
      _logger.info(
        'SyncService: Removed ${successIds.length} successful mutations from queue',
      );
    }

    for (final failed in failedIds) {
      final cid = failed.key;
      final error = failed.value;
      final mutation = mutations.firstWhere(
        (m) => m['id'] == cid,
        orElse: () => {},
      );
      final retryCount = mutation['retry_count'] as int? ?? 0;

      if (retryCount >= _maxRetries) {
        _logger.error(
          'SyncService: Mutation $cid exceeded max retries ($_maxRetries). Dropping. Error: $error',
        );
        await _syncRepo.removeMutation(cid);
      } else {
        await _syncRepo.incrementRetryCount(cid);
        _logger.warning(
          'SyncService: Mutation $cid failed (status ${response.statusCode}), '
          'retry count: ${retryCount + 1}. Error: $error',
        );
      }
    }
  }

  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> performDeltaSync() async {
    if (!_ref.read(connectivityProvider)) return;

    try {
      final lastSync = await _db.getLastSyncTimestamp();
      final delta = await _syncRemote.fetchDelta(lastSync);

      if (delta.changes.isEmpty) {
        await _db.updateLastSyncTimestamp(delta.syncTimestamp);
        _logger.info('SyncService: No remote changes found.');
        return;
      }

      // Offload transformation to Isolate to keep UI thread smooth
      final processedChanges = await Isolate.run(
        () => _processChanges(delta.changes),
      );

      final db = await _db.database;
      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final change in processedChanges) {
          final table = change['table'] as String;
          final type = change['type'] as String;
          final data = change['data'] as Map<String, dynamic>;
          final pkColumn = table == 'vocabularies' ? 'word' : 'id';

          if (type == 'update') {
            batch.insert(
              table,
              data,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else if (type == 'delete') {
            batch.delete(
              table,
              where: '$pkColumn = ?',
              whereArgs: [data[pkColumn]],
            );
          }
        }

        await batch.commit(noResult: true);
        await _db.updateLastSyncTimestamp(delta.syncTimestamp);
      });

      _logger.info('SyncService: Applied ${delta.changes.length} changes.');

      // Recursive call if server indicates more data (pagination)
      if (delta.hasMore) {
        await performDeltaSync();
      }
    } catch (e, st) {
      _logger.error('SyncService: Incremental sync failed', e, st);
    }
  }

  static List<Map<String, dynamic>> _processChanges(List<dynamic> changes) {
    return changes.map((c) {
      final entity = c['entity'] as String;
      final type = c['type'] as String;
      final rawData = c['data'] as Map<String, dynamic>;

      String table;
      Map<String, dynamic> mappedData;

      switch (entity) {
        case 'vocabulary':
          table = 'vocabularies';
          mappedData = {
            'word': rawData['word'].toString().toLowerCase(),
            'status': rawData['status'].toString().toLowerCase(),
            'language': rawData['language'] ?? 'unknown',
            'last_synced_at': DateTime.now().millisecondsSinceEpoch,
          };
          break;
        case 'srs':
          table = 'srs_items';
          mappedData = {
            'id': rawData['id'],
            'front': rawData['frontContent'] ?? '',
            'back': rawData['backContent'] ?? '',
            'context': rawData['context'],
            'type': rawData['type'] ?? 'TRANSLATION',
            'next_review_date': DateTime.parse(
              rawData['nextReviewDate'],
            ).millisecondsSinceEpoch,
          };
          break;
        case 'journal':
          table = 'journals';
          mappedData = {
            'id': rawData['id'],
            'content': rawData['content'] ?? '',
            'title': rawData['topic']?['title'] ?? 'Free Write',
            'created_at': DateTime.parse(
              rawData['createdAt'],
            ).millisecondsSinceEpoch,
            'audio_url': rawData['audioUrl'],
            'analysis_json': rawData['analysis'] != null
                ? jsonEncode(rawData['analysis'])
                : null,
          };
          break;
        case 'book':
          table = 'books';
          mappedData = {
            'id': rawData['id'],
            'title': rawData['title'] ?? 'Unknown Title',
            'author': rawData['author'],
            'target_language': rawData['targetLanguage'] ?? 'spanish',
            'storage_path': rawData['storagePath'] ?? '',
            'cover_image_url': rawData['coverImageUrl'],
            'current_cfi': rawData['currentCfi'],
            'progress_pct': (rawData['progressPct'] ?? 0).toDouble(),
            'created_at': DateTime.parse(
              rawData['createdAt'],
            ).millisecondsSinceEpoch,
          };
          break;
        default:
          throw Exception('Unknown entity type: $entity');
      }

      return {'table': table, 'type': type, 'data': mappedData};
    }).toList();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final client = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  final syncRemote = ref.watch(syncRemoteDataSourceProvider);
  final service = SyncService(syncRepo, client, ref, logger, db, syncRemote);
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

final lastSyncTimeProvider = NotifierProvider<LastSyncTimeNotifier, DateTime?>(
  () => LastSyncTimeNotifier(),
);

class IsSyncingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final isSyncingProvider = NotifierProvider<IsSyncingNotifier, bool>(
  () => IsSyncingNotifier(),
);
