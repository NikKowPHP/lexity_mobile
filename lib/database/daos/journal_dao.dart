import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class JournalDao {
  final AppDatabase _appDb;

  JournalDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<int> insertJournal(Map<String, dynamic> journal) async {
    final db = await _database;
    final result = await db.insert(
      'journals',
      journal,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _appDb.notify('journals');
    return result;
  }

  Future<Map<String, dynamic>?> getJournalById(String id) async {
    final db = await _database;
    final results = await db.query(
      'journals',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllJournals() async {
    final db = await _database;
    return await db.query('journals', orderBy: 'created_at DESC');
  }

  Stream<List<Map<String, dynamic>>> watchAllJournals() async* {
    yield await getAllJournals();
    yield* _appDb.getController('journals').stream;
  }

  Future<void> insertJournalsBatch(List<Map<String, dynamic>> items) async {
    final db = await _database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'journals',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _appDb.notify('journals');
  }
}
