import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class SyncQueueDao {
  final AppDatabase _appDb;

  SyncQueueDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<void> compactSyncQueue() async {
    final db = await _database;
    await db.transaction((txn) async {
      // For book progress updates, keep only the most recent entry per book_id
      await txn.execute('''
        DELETE FROM sync_queue
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM sync_queue
          WHERE entity_type = 'book' AND action = 'update_progress'
          GROUP BY entity_id
        )
        AND entity_type = 'book' AND action = 'update_progress'
      ''');

      // For vocabulary updates, keep only the most recent entry per word
      await txn.execute('''
        DELETE FROM sync_queue
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM sync_queue
          WHERE entity_type = 'vocabulary' AND action = 'update'
          GROUP BY entity_id
        )
        AND entity_type = 'vocabulary' AND action = 'update'
      ''');
    });
    _appDb.notify('sync_queue');
  }

  Future<int> enqueueMutation(Map<String, dynamic> mutation) async {
    final db = await _database;

    if (mutation['entity_type'] == 'book' &&
        mutation['action'] == 'update_progress') {
      await db.delete(
        'sync_queue',
        where: 'entity_type = ? AND action = ? AND entity_id = ?',
        whereArgs: ['book', 'update_progress', mutation['entity_id']],
      );
    }

    final result = await db.insert('sync_queue', {
      ...mutation,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    _appDb.notify('sync_queue');
    return result;
  }

  Future<List<Map<String, dynamic>>> getPendingMutations({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _database;
    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
  }

  Stream<List<Map<String, dynamic>>> watchPendingMutations() async* {
    yield await getPendingMutations();
    yield* _appDb.getController('sync_queue').stream;
  }

  Future<int> getPendingMutationsCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> removeMutation(int id) async {
    final db = await _database;
    final result = await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    _appDb.notify('sync_queue');
    return result;
  }

  Future<int> removeMutations(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'sync_queue',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    _appDb.notify('sync_queue');
    return result;
  }

  Future<int> incrementRetryCount(int id) async {
    final db = await _database;
    return await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> clearSyncQueue() async {
    final db = await _database;
    await db.delete('sync_queue');
    _appDb.notify('sync_queue');
  }
}
