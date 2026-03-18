import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../utils/constants.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import 'logger_service.dart';
import 'sync_service.dart';

class VocabularyCounts {
  final int total;
  final int known;
  final int learning;
  final int unknown;

  VocabularyCounts({
    required this.total,
    required this.known,
    required this.learning,
    required this.unknown,
  });
}

class VocabularyPageResult {
  final Map<String, String> items;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final VocabularyCounts counts;

  VocabularyPageResult({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.counts,
  });
}

class VocabularyService {
  final TokenService _authTokenService;
  final AppDatabase _db;
  final SyncRepository _syncRepo;
  final Ref _ref;
  late final LoggerService _logger;

  VocabularyService(
    this._authTokenService,
    this._db,
    this._syncRepo,
    this._ref,
  ) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> getVocabulary(String language) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse(
            '${AppConstants.baseUrl}/api/vocabulary?targetLanguage=$language',
          ),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);

          for (final entry in data.entries) {
            await _db.insertVocabulary({
              'word': entry.key.toLowerCase(),
              'status': entry.value.toString().toLowerCase(),
              'language': language,
              'last_synced_at': DateTime.now().millisecondsSinceEpoch,
            });
          }

          return data.map(
            (key, value) =>
                MapEntry(key.toLowerCase(), value.toString().toLowerCase()),
          );
        }
      } catch (e, st) {
        _logger.warning(
          'VocabularyService: Failed to fetch from backend',
          e,
          st,
        );
      }
    }

    return _getLocalVocabulary();
  }

  Future<Map<String, String>> _getLocalVocabulary() async {
    final items = await _db.getAllVocabularies();
    final result = <String, String>{};
    for (final item in items) {
      result[item['word'] as String] = item['status'] as String;
    }
    return result;
  }

  Future<VocabularyPageResult> getVocabularyPage(String language, {int page = 1, int limit = 50, String? status}) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        var url = '${AppConstants.baseUrl}/api/vocabulary?targetLanguage=$language&page=$page&limit=$limit';
        if (status != null) {
          url += '&status=$status';
        }
        
        final response = await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = data['items'] as Map<String, dynamic>;
          final pagination = data['pagination'] as Map<String, dynamic>;
          final counts = data['counts'] as Map<String, dynamic>;

          for (final entry in items.entries) {
            await _db.insertVocabulary({
              'word': entry.key.toLowerCase(),
              'status': entry.value.toString().toLowerCase(),
              'language': language,
              'last_synced_at': DateTime.now().millisecondsSinceEpoch,
            });
          }

          return VocabularyPageResult(
            items: items.map((key, value) => MapEntry(key.toLowerCase(), value.toString().toLowerCase())),
            totalCount: pagination['totalCount'] as int,
            totalPages: pagination['totalPages'] as int,
            currentPage: pagination['page'] as int,
            counts: VocabularyCounts(
              total: counts['total'] as int,
              known: counts['known'] as int,
              learning: counts['learning'] as int,
              unknown: counts['unknown'] as int,
            ),
          );
        }
      } catch (e, st) {
        _logger.warning('VocabularyService: Failed to fetch paginated vocabulary', e, st);
      }
    }

    return _getLocalVocabularyPage(language);
  }

  Future<VocabularyPageResult> _getLocalVocabularyPage(String language) async {
    final items = await _db.getAllVocabularies();
    final result = <String, String>{};
    int known = 0, learning = 0, unknown = 0;
    
    for (final item in items) {
      final word = item['word'] as String;
      final status = item['status'] as String;
      result[word] = status;
      if (status == 'known') known++;
      else if (status == 'learning') learning++;
      else unknown++;
    }

    return VocabularyPageResult(
      items: result,
      totalCount: items.length,
      totalPages: 1,
      currentPage: 1,
      counts: VocabularyCounts(
        total: items.length,
        known: known,
        learning: learning,
        unknown: unknown,
      ),
    );
  }

  Future<void> updateStatus(String word, String status, String language) async {
    _logger.info(
      'VocabularyService: Updating status for "$word" to "$status" locally',
    );

    await _db.insertVocabulary({
      'word': word.toLowerCase(),
      'status': status.toLowerCase(),
      'language': language,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });

    await _syncRepo.enqueueVocabUpdate(
      word.toLowerCase(),
      status,
      language,
    );

    _logger.info('VocabularyService: Status update queued for sync');

    if (_ref.read(connectivityProvider)) {
      _logger.info('VocabularyService: Online, triggering immediate sync...');
      _ref.read(syncServiceProvider).syncPendingMutations(force: true);
    }
  }

  Future<void> markBatchKnown(List<String> words, String language) async {
    _logger.info(
      'VocabularyService: Marking ${words.length} words as known locally',
    );

    final lowerWords = words.map((w) => w.toLowerCase()).toList();
    
    for (final word in lowerWords) {
      await _db.insertVocabulary({
        'word': word,
        'status': 'known',
        'language': language,
        'last_synced_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await _syncRepo.enqueueVocabBatchUpdate(lowerWords, 'known', language);

    _logger.info('VocabularyService: Batch update queued for sync');

    if (_ref.read(connectivityProvider)) {
      _logger.info('VocabularyService: Online, triggering immediate sync...');
      _ref.read(syncServiceProvider).syncPendingMutations(force: true);
    }
  }

  Future<void> deleteWord(String word, String language) async {
    _logger.info('VocabularyService: Deleting word "$word" locally');
    await _db.deleteVocabulary(word.toLowerCase());
  }

  Stream<Map<String, String>> watchVocabulary() {
    return _db.watchAllVocabularies().map((items) {
      final result = <String, String>{};
      for (final item in items) {
        result[item['word'] as String] = item['status'] as String;
      }
      return result;
    });
  }
}

final vocabularyServiceProvider = Provider(
  (ref) => VocabularyService(
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(databaseProvider),
    ref.watch(syncRepositoryProvider),
    ref,
  ),
);
