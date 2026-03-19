import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class VocabularyDao {
  final AppDatabase _appDb;

  VocabularyDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<int> insertVocabulary(Map<String, dynamic> vocab) async {
    final db = await _database;
    final result = await db.insert(
      'vocabularies',
      vocab,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _appDb.notify('vocabularies');
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllVocabularies() async {
    final db = await _database;
    return await db.query('vocabularies');
  }

  Future<List<Map<String, dynamic>>> getVocabulariesByLanguage(
    String language,
  ) async {
    final db = await _database;
    return await db.query(
      'vocabularies',
      where: 'language = ?',
      whereArgs: [language],
    );
  }

  Stream<List<Map<String, dynamic>>> watchAllVocabularies() async* {
    yield await getAllVocabularies();
    yield* _appDb.getController('vocabularies').stream;
  }

  Future<int> deleteVocabulary(String word) async {
    final db = await _database;
    final result = await db.delete(
      'vocabularies',
      where: 'word = ?',
      whereArgs: [word],
    );
    _appDb.notify('vocabularies');
    return result;
  }

  Future<void> insertVocabularyBatch(List<Map<String, dynamic>> items) async {
    final db = await _database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'vocabularies',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _appDb.notify('vocabularies');
  }

  Future<List<String>> getVocabularyLanguages() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT DISTINCT language FROM vocabularies WHERE language IS NOT NULL AND language != ?',
      ['unknown'],
    );
    return result.map((row) => row['language'] as String).toList();
  }
}
