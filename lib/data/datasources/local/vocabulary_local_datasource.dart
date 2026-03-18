import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';

class VocabularyLocalDataSource {
  final AppDatabase _db;

  VocabularyLocalDataSource(this._db);

  Future<Map<String, String>> getVocabulary(String language) async {
    final items = await _db.getVocabulariesByLanguage(language);
    final result = <String, String>{};
    for (final item in items) {
      result[item['word'] as String] = item['status'] as String;
    }
    return result;
  }

  Future<Map<String, String>> getAllVocabulary() async {
    final items = await _db.getAllVocabularies();
    final result = <String, String>{};
    for (final item in items) {
      result[item['word'] as String] = item['status'] as String;
    }
    return result;
  }

  Future<void> upsertFromRemote(
    Map<String, dynamic> data,
    String language,
  ) async {
    await _db.insertVocabulary({
      'word': data['word'].toString().toLowerCase(),
      'status': data['status'].toString().toLowerCase(),
      'language': language,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> upsertBatch(
    List<Map<String, dynamic>> items,
    String language,
  ) async {
    final batchItems = items
        .map(
          (item) => {
            'word': item['word'].toString().toLowerCase(),
            'status': item['status'].toString().toLowerCase(),
            'language': language,
            'last_synced_at': DateTime.now().millisecondsSinceEpoch,
          },
        )
        .toList();
    await _db.insertVocabularyBatch(batchItems);
  }

  Future<void> updateStatus(String word, String status, String language) async {
    await _db.insertVocabulary({
      'word': word.toLowerCase(),
      'status': status.toLowerCase(),
      'language': language,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteWord(String word) async {
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

  Future<List<String>> getLanguages() async {
    return _db.getVocabularyLanguages();
  }
}

final vocabularyLocalDataSourceProvider = Provider<VocabularyLocalDataSource>((
  ref,
) {
  return VocabularyLocalDataSource(ref.watch(databaseProvider));
});
