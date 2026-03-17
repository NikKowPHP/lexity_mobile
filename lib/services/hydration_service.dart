import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/connectivity_provider.dart';
import '../services/token_service.dart';
import '../utils/constants.dart';
import '../services/logger_service.dart';

class HydrationService {
  final AppDatabase _db;
  final Ref _ref;
  final LoggerService _logger;
  DateTime? _lastSyncTimestamp;

  HydrationService(this._db, this._ref, this._logger);

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<Map<String, String>> _getHeaders() async {
    final tokenService = _ref.read(tokenServiceProvider(TokenType.auth));
    final token = await tokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> performFullSync() async {
    if (!_isOnline) {
      _logger.info('HydrationService: Offline, skipping full sync');
      return;
    }

    _logger.info('HydrationService: Starting full sync...');

    try {
      await Future.wait([
        _syncBooks(),
        _syncJournals(),
        _syncSrsItems(),
        _syncVocabulary(),
      ]);

      _lastSyncTimestamp = DateTime.now();
      _logger.info(
        'HydrationService: Full sync completed at $_lastSyncTimestamp',
      );
    } catch (e, st) {
      _logger.error('HydrationService: Full sync failed', e, st);
      rethrow;
    }
  }

  Future<void> _syncBooks() async {
    _logger.info('HydrationService: Syncing books...');
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/books'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _logger.info('HydrationService: Syncing ${data.length} books');

        for (final item in data) {
          await _db.insertBook({
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
            'last_synced_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e, st) {
      _logger.error('HydrationService: Book sync failed', e, st);
    }
  }

  Future<void> _syncJournals() async {
    _logger.info('HydrationService: Syncing journals...');
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/journal'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _logger.info('HydrationService: Syncing ${data.length} journals');

        for (final item in data) {
          final analysis = item['analysis'];
          await _db.insertJournal({
            'id': item['id'],
            'content': item['content'] ?? '',
            'title': item['topic']?['title'] ?? 'Free Write',
            'created_at': DateTime.parse(
              item['createdAt'],
            ).millisecondsSinceEpoch,
            'audio_url': item['audioUrl'],
            'is_pending_analysis': analysis == null ? 0 : 0,
            'analysis_json': analysis != null ? jsonEncode(analysis) : null,
            'last_synced_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e, st) {
      _logger.error('HydrationService: Journal sync failed', e, st);
    }
  }

  Future<void> _syncSrsItems() async {
    _logger.info('HydrationService: Syncing SRS items...');
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/srs/all'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _logger.info('HydrationService: Syncing ${data.length} SRS items');

        for (final item in data) {
          final nextReview = item['nextReviewDate'] != null
              ? DateTime.parse(item['nextReviewDate']).millisecondsSinceEpoch
              : DateTime.now()
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch;

          await _db.insertSrsItem({
            'id': item['id'],
            'front': item['frontContent'] ?? '',
            'back': item['backContent'] ?? '',
            'context': item['context'],
            'type': item['type'] ?? 'TRANSLATION',
            'next_review_date': nextReview,
            'last_synced_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e, st) {
      _logger.error('HydrationService: SRS sync failed', e, st);
    }
  }

  Future<void> _syncVocabulary() async {
    _logger.info('HydrationService: Syncing vocabulary...');
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/vocabulary/all'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _logger.info(
          'HydrationService: Syncing ${data.length} vocabulary items',
        );

        for (final entry in data.entries) {
          await _db.insertVocabulary({
            'word': entry.key.toLowerCase(),
            'status': entry.value.toString().toLowerCase(),
            'language': 'unknown',
            'last_synced_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e, st) {
      _logger.error('HydrationService: Vocabulary sync failed', e, st);
    }
  }

  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;
}

final hydrationServiceProvider = Provider<HydrationService>((ref) {
  final db = ref.watch(databaseProvider);
  final logger = ref.watch(loggerProvider);
  return HydrationService(db, ref, logger);
});

final hydrationTriggerProvider = FutureProvider<void>((ref) async {
  final hydrationService = ref.watch(hydrationServiceProvider);
  await hydrationService.performFullSync();
});
