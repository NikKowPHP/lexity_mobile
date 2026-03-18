import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/utils/constants.dart';
import '../database/app_database.dart';
import '../providers/connectivity_provider.dart';
import '../services/logger_service.dart';
import '../services/sync_service.dart';
import '../network/api_client.dart';

class HydrationService {
  final AppDatabase _db;
  final Ref _ref;
  final ApiClient _client;
  final LoggerService _logger;
  DateTime? _lastSyncTimestamp;

  HydrationService(this._db, this._ref, this._client, this._logger);

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<void> performFullSync() async {
    if (!_isOnline) {
      _logger.info('HydrationService: Offline, skipping full sync');
      return;
    }

    _logger.info('HydrationService: Starting full sync...');

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchBooks(),
        _fetchJournals(),
        _fetchSrsItems(),
        _fetchVocabulary(),
      ]);

      final booksData = results[0];
      final journalsData = results[1];
      final srsData = results[2];
      final vocabData = results[3];

      _logger.info(
        'HydrationService: Fetched ${booksData.length} books, ${journalsData.length} journals, ${srsData.length} SRS items, ${vocabData.length} vocabulary items',
      );

      // Atomic database insertion
      final db = await _db.database;
      await db.transaction((txn) async {
        if (booksData.isNotEmpty) {
          await _db.insertBooksBatch(booksData);
        }
        if (journalsData.isNotEmpty) {
          await _db.insertJournalsBatch(journalsData);
        }
        if (srsData.isNotEmpty) {
          await _db.insertSrsBatch(srsData);
        }
        if (vocabData.isNotEmpty) {
          await _db.insertVocabularyBatch(vocabData);
        }
      });

      _lastSyncTimestamp = DateTime.now();
      _ref.read(lastSyncTimeProvider.notifier).state = _lastSyncTimestamp;
      _logger.info(
        'HydrationService: Full sync completed at $_lastSyncTimestamp',
      );
    } catch (e, st) {
      _logger.error('HydrationService: Full sync failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBooks() async {
    _logger.info('HydrationService: Fetching books...');
    try {
      final queryParams = <String, dynamic>{};
      if (_lastSyncTimestamp != null) {
        queryParams['since'] = _lastSyncTimestamp!.millisecondsSinceEpoch
            .toString();
      }

      final response = await _client.get(
        '/api/books',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List data = response.data;
        _logger.info('HydrationService: Fetched ${data.length} books');
        final now = DateTime.now().millisecondsSinceEpoch;
        
        return data.map<Map<String, dynamic>>((item) {
          return {
            'id': item['id'],
            'title': item['title'] ?? 'Unknown Title',
            'author': item['author'],
            'target_language': item['targetLanguage'] ?? 'spanish',
            'storage_path': item['storagePath'] ?? '',
            'cover_image_url': item['coverImageUrl'],
            'current_cfi': item['currentCfi'],
            'progress_pct': (item['progressPct'] ?? 0).toDouble(),
            'created_at': DateTime.parse(
              item['createdAt'],
            ).millisecondsSinceEpoch,
            'signed_url': item['signedUrl']?.startsWith('/') == true
                ? '${AppConstants.baseUrl}${item['signedUrl']}'
                : item['signedUrl'],
            'locations': item['locations'],
            'last_synced_at': now,
          };
        }).toList();
      }
      return [];
    } catch (e, st) {
      _logger.error('HydrationService: Book fetch failed', e, st);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchJournals() async {
    _logger.info('HydrationService: Fetching journals...');
    try {
      final queryParams = <String, dynamic>{};
      if (_lastSyncTimestamp != null) {
        queryParams['since'] = _lastSyncTimestamp!.millisecondsSinceEpoch
            .toString();
      }

      final response = await _client.get(
        '/api/journal',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List data = response.data;
        _logger.info('HydrationService: Fetched ${data.length} journals');
        final now = DateTime.now().millisecondsSinceEpoch;

        return data.map<Map<String, dynamic>>((item) {
          final analysis = item['analysis'];
          return {
            'id': item['id'],
            'content': item['content'] ?? '',
            'title': item['topic']?['title'] ?? 'Free Write',
            'created_at': DateTime.parse(
              item['createdAt'],
            ).millisecondsSinceEpoch,
            'audio_url': item['audioUrl'],
            'is_pending_analysis': analysis == null ? 0 : 0,
            'analysis_json': analysis != null ? jsonEncode(analysis) : null,
            'last_synced_at': now,
          };
        }).toList();
      }
      return [];
    } catch (e, st) {
      _logger.error('HydrationService: Journal fetch failed', e, st);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSrsItems() async {
    _logger.info('HydrationService: Fetching SRS items...');
    try {
      final queryParams = <String, dynamic>{};
      if (_lastSyncTimestamp != null) {
        queryParams['since'] = _lastSyncTimestamp!.millisecondsSinceEpoch
            .toString();
      }

      final response = await _client.get(
        '/api/srs/all',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List data = response.data;
        _logger.info('HydrationService: Fetched ${data.length} SRS items');
        final now = DateTime.now().millisecondsSinceEpoch;

        return data.map<Map<String, dynamic>>((item) {
          final nextReview = item['nextReviewDate'] != null
              ? DateTime.parse(item['nextReviewDate']).millisecondsSinceEpoch
              : DateTime.now()
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch;

          return {
            'id': item['id'],
            'front': item['frontContent'] ?? '',
            'back': item['backContent'] ?? '',
            'context': item['context'],
            'type': item['type'] ?? 'TRANSLATION',
            'next_review_date': nextReview,
            'last_synced_at': now,
          };
        }).toList();
      }
      return [];
    } catch (e, st) {
      _logger.error('HydrationService: SRS fetch failed', e, st);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVocabulary() async {
    _logger.info('HydrationService: Fetching vocabulary...');
    try {
      final queryParams = <String, dynamic>{};
      if (_lastSyncTimestamp != null) {
        queryParams['since'] = _lastSyncTimestamp!.millisecondsSinceEpoch
            .toString();
      }

      final response = await _client.get(
        '/api/vocabulary/all',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        _logger.info(
          'HydrationService: Fetched ${data.length} vocabulary items',
        );

        // OFFLOAD MAPPING TO ISOLATE
        final List<Map<String, dynamic>> batchItems = await Isolate.run(() {
          final now = DateTime.now().millisecondsSinceEpoch;
          return data.entries.map((entry) => {
            'word': entry.key.toLowerCase(),
            'status': entry.value.toString().toLowerCase(),
            'language': 'unknown',
            'last_synced_at': now,
          }).toList();
        });

        return batchItems;
      }
      return [];
    } catch (e, st) {
      _logger.error('HydrationService: Vocabulary fetch failed', e, st);
      return [];
    }
  }

  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;
}

final hydrationServiceProvider = Provider<HydrationService>((ref) {
  final db = ref.watch(databaseProvider);
  final logger = ref.watch(loggerProvider);
  final client = ref.watch(apiClientProvider);
  return HydrationService(db, ref, client, logger);
});

final hydrationTriggerProvider = FutureProvider<void>((ref) async {
  final hydrationService = ref.watch(hydrationServiceProvider);
  await hydrationService.performFullSync();
});
