import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../models/book.dart';

class BookLocalDataSource {
  final AppDatabase _db;

  BookLocalDataSource(this._db);

  Future<List<UserBook>> getAllBooks() async {
    final books = await _db.getAllBooks();
    return books.map((map) => _userBookFromDb(map)).toList();
  }

  Future<UserBook?> getBookById(String id) async {
    final book = await _db.getBookById(id);
    if (book == null) return null;
    return _userBookFromDb(book);
  }

  Future<void> upsertFromRemote(Map<String, dynamic> data) async {
    await _db.insertBook({
      'id': data['id'],
      'title': data['title'] ?? 'Unknown Title',
      'author': data['author'],
      'target_language': data['targetLanguage'] ?? 'spanish',
      'storage_path': data['storagePath'] ?? '',
      'cover_image_url': data['coverImageUrl'],
      'current_cfi': data['currentCfi'],
      'progress_pct': (data['progressPct'] ?? 0).toDouble(),
      'created_at': data['createdAt'] is DateTime
          ? data['createdAt'].millisecondsSinceEpoch
          : DateTime.parse(data['createdAt']).millisecondsSinceEpoch,
      'signed_url': data['signedUrl'],
      'locations': data['locations'],
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> insertBook(Map<String, dynamic> data) async {
    await _db.insertBook(data);
  }

  Future<void> updateProgress(String id, String cfi, double progress) async {
    await _db.updateBookProgress(id, cfi, progress);
  }

  Future<void> deleteBook(String id) async {
    await _db.deleteBook(id);
  }

  Stream<List<UserBook>> watchBooks() {
    return _db.watchAllBooks().map(
      (books) => books.map((map) => _userBookFromDb(map)).toList(),
    );
  }

  UserBook _userBookFromDb(Map<String, dynamic> map) {
    return UserBook(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      targetLanguage: map['target_language'] as String,
      storagePath: map['storage_path'] as String,
      coverImageUrl: map['cover_image_url'] as String?,
      currentCfi: map['current_cfi'] as String?,
      progressPct: (map['progress_pct'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      signedUrl: map['signed_url'] as String?,
      locations: map['locations'] as String?,
    );
  }
}

final bookLocalDataSourceProvider = Provider<BookLocalDataSource>((ref) {
  return BookLocalDataSource(ref.watch(databaseProvider));
});
