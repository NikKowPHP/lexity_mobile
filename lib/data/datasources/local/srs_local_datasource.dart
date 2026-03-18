import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../models/srs_item.dart';

class SrsLocalDataSource {
  final AppDatabase _db;

  SrsLocalDataSource(this._db);

  Future<List<SrsItem>> getDueItems() async {
    final items = await _db.getDueSrsItems();
    return items.map((map) => _srsItemFromDb(map)).toList();
  }

  Future<List<SrsItem>> getAllItems() async {
    final items = await _db.getAllSrsItems();
    return items.map((map) => _srsItemFromDb(map)).toList();
  }

  Future<void> upsertFromRemote(Map<String, dynamic> data) async {
    final nextReview = data['nextReviewDate'] != null
        ? DateTime.parse(data['nextReviewDate']).millisecondsSinceEpoch
        : DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;

    await _db.insertSrsItem({
      'id': data['id'],
      'front': data['frontContent'] ?? '',
      'back': data['backContent'] ?? '',
      'context': data['context'],
      'type': data['type'] ?? 'TRANSLATION',
      'next_review_date': nextReview,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateReviewDate(String id, DateTime nextReview) async {
    await _db.updateSrsItemReviewDate(id, nextReview);
  }

  Future<void> deleteItem(String id) async {
    final db = await _db.database;
    await db.delete('srs_items', where: 'id = ?', whereArgs: [id]);
  }

  Stream<List<SrsItem>> watchDueItems() {
    return _db.watchDueSrsItems().map(
      (items) => items.map((map) => _srsItemFromDb(map)).toList(),
    );
  }

  SrsItem _srsItemFromDb(Map<String, dynamic> map) {
    return SrsItem(
      id: map['id'] as String,
      front: map['front'] as String,
      back: map['back'] as String,
      context: map['context'] as String?,
      type: map['type'] as String? ?? 'TRANSLATION',
    );
  }
}

final srsLocalDataSourceProvider = Provider<SrsLocalDataSource>((ref) {
  return SrsLocalDataSource(ref.watch(databaseProvider));
});
