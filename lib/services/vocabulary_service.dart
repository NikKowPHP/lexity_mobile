import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../utils/constants.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import 'logger_service.dart';

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
      status.toLowerCase(),
    );

    _logger.info('VocabularyService: Status update queued for sync');
  }

  Future<void> markBatchKnown(List<String> words, String language) async {
    _logger.info(
      'VocabularyService: Marking ${words.length} words as known locally',
    );

    for (final word in words) {
      await _db.insertVocabulary({
        'word': word.toLowerCase(),
        'status': 'known',
        'language': language,
        'last_synced_at': DateTime.now().millisecondsSinceEpoch,
      });

      await _syncRepo.enqueueVocabUpdate(word.toLowerCase(), 'known');
    }

    _logger.info('VocabularyService: Batch update queued for sync');
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
