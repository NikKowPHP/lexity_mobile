import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_database.dart';

class SyncRepository {
  final AppDatabase _db;

  SyncRepository(this._db);

  Future<void> enqueueMutation({
    required String entityType,
    required String action,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.enqueueMutation({
      'entity_type': entityType,
      'action': action,
      'entity_id': entityId,
      'payload_json': jsonEncode(payload),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingMutations({
    int limit = 50,
    int offset = 0,
  }) async {
    return await _db.getPendingMutations(limit: limit, offset: offset);
  }

  Stream<List<Map<String, dynamic>>> watchPendingMutations() {
    return _db.watchPendingMutations();
  }

  Future<int> getPendingCount() async {
    return await _db.getPendingMutationsCount();
  }

  Future<void> removeMutation(int id) async {
    await _db.removeMutation(id);
  }

  Future<void> removeMutations(List<int> ids) async {
    await _db.removeMutations(ids);
  }

  Future<void> incrementRetryCount(int id) async {
    await _db.incrementRetryCount(id);
  }

  Future<void> clearQueue() async {
    await _db.clearSyncQueue();
  }

  Future<void> compactSyncQueue() async {
    await _db.compactSyncQueue();
  }

  // Book mutations
  Future<void> enqueueBookProgress(
    String bookId,
    String cfi,
    double progressPct,
  ) async {
    await enqueueMutation(
      entityType: 'book',
      action: 'update_progress',
      entityId: bookId,
      payload: {
        'bookId': bookId,
        'currentCfi': cfi,
        'progressPct': progressPct,
      },
    );
  }

  Future<void> enqueueBookDelete(String bookId) async {
    await enqueueMutation(
      entityType: 'book',
      action: 'delete',
      entityId: bookId,
      payload: {},
    );
  }

  // Journal mutations
  Future<void> enqueueJournalCreate(
    String journalId,
    String title,
    String content,
    String targetLanguage,
    String? moduleId,
    String mode,
  ) async {
    await enqueueMutation(
      entityType: 'journal',
      action: 'create',
      entityId: journalId,
      payload: {
        'title': title,
        'content': content,
        'targetLanguage': targetLanguage,
        'moduleId': moduleId,
        'mode': mode,
      },
    );
  }

  // SRS mutations
  Future<void> enqueueSrsReview(String itemId, DateTime nextReviewDate) async {
    await enqueueMutation(
      entityType: 'srs',
      action: 'review',
      entityId: itemId,
      payload: {
        'itemId': itemId,
        'nextReviewDate': nextReviewDate.toIso8601String(),
      },
    );
  }

  // Vocabulary mutations
  Future<void> enqueueVocabUpdate(
    String word,
    String status,
    String targetLanguage,
  ) async {
    await enqueueMutation(
      entityType: 'vocabulary',
      action: 'update',
      entityId: word,
      payload: {
        'word': word,
        'status': status.toUpperCase(),
        'targetLanguage': targetLanguage,
      },
    );
  }

  Future<void> enqueueVocabBatchUpdate(
    List<String> words,
    String status,
    String targetLanguage,
  ) async {
    await enqueueMutation(
      entityType: 'vocabulary',
      action: 'batch_update',
      entityId: 'batch_${DateTime.now().millisecondsSinceEpoch}',
      payload: {
        'words': words,
        'status': status.toUpperCase(),
        'targetLanguage': targetLanguage,
      },
    );
  }

  // User profile mutations
  Future<void> enqueueProfileUpdate(Map<String, dynamic> data) async {
    await enqueueMutation(
      entityType: 'user',
      action: 'update_profile',
      entityId: 'current_user',
      payload: data,
    );
  }
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncRepository(db);
});
