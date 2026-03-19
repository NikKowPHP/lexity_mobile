import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class BookDao {
  final AppDatabase _appDb;

  BookDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await _database;
    final result = await db.insert(
      'books',
      book,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _appDb.notify('books');
    return result;
  }

  Future<Map<String, dynamic>?> getBookById(String id) async {
    final db = await _database;
    final results = await db.query('books', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await _database;
    return await db.query('books');
  }

  Stream<List<Map<String, dynamic>>> watchAllBooks() async* {
    yield await getAllBooks();
    yield* _appDb.getController('books').stream;
  }

  Future<int> updateBookProgress(String id, String cfi, double progress) async {
    final db = await _database;
    final result = await db.update(
      'books',
      {'current_cfi': cfi, 'progress_pct': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
    _appDb.notify('books');
    return result;
  }

  Future<int> deleteBook(String id) async {
    final db = await _database;
    final result = await db.delete('books', where: 'id = ?', whereArgs: [id]);
    _appDb.notify('books');
    return result;
  }

  Future<void> insertBooksBatch(List<Map<String, dynamic>> items) async {
    final db = await _database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('books', item, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _appDb.notify('books');
  }
}
