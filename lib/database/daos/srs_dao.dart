import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class SrsDao {
  final AppDatabase _appDb;

  SrsDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<int> insertSrsItem(Map<String, dynamic> item) async {
    final db = await _database;
    final result = await db.insert(
      'srs_items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _appDb.notify('srs_items');
    _notifyDueSrsItems();
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllSrsItems() async {
    final db = await _database;
    return await db.query('srs_items');
  }

  Stream<List<Map<String, dynamic>>> watchAllSrsItems() async* {
    yield await getAllSrsItems();
    yield* _appDb.getController('srs_items').stream;
  }

  Future<List<Map<String, dynamic>>> getDueSrsItems() async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query(
      'srs_items',
      where: 'next_review_date <= ?',
      whereArgs: [now],
    );
  }

  void _notifyDueSrsItems() async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = await db.query(
      'srs_items',
      where: 'next_review_date <= ?',
      whereArgs: [now],
    );
    _appDb.getController('due_srs_items').add(data);
  }

  Stream<List<Map<String, dynamic>>> watchDueSrsItems() async* {
    yield await getDueSrsItems();
    yield* _appDb.getController('due_srs_items').stream;
    yield* Stream.periodic(
      const Duration(minutes: 1),
    ).asyncMap((_) => getDueSrsItems());
  }

  Future<int> updateSrsItemReviewDate(String id, DateTime nextReview) async {
    final db = await _database;
    final result = await db.update(
      'srs_items',
      {'next_review_date': nextReview.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    _appDb.notify('srs_items');
    _notifyDueSrsItems();
    return result;
  }

  Future<void> insertSrsBatch(List<Map<String, dynamic>> items) async {
    final db = await _database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'srs_items',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _appDb.notify('srs_items');
    _notifyDueSrsItems();
  }
}
