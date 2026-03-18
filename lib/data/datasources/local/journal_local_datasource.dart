import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../models/journal_entry.dart';

class JournalLocalDataSource {
  final AppDatabase _db;

  JournalLocalDataSource(this._db);

  Future<List<JournalEntry>> getAllJournals() async {
    final journals = await _db.getAllJournals();
    return journals.map((map) => _journalFromDb(map)).toList();
  }

  Future<JournalEntry?> getJournalById(String id) async {
    final journal = await _db.getJournalById(id);
    if (journal == null) return null;
    return _journalFromDb(journal);
  }

  Future<void> insertJournal(Map<String, dynamic> data) async {
    await _db.insertJournal({
      'id': data['id'],
      'content': data['content'] ?? '',
      'title': data['title'] ?? 'Free Write',
      'created_at': data['createdAt'] is DateTime
          ? data['createdAt'].millisecondsSinceEpoch
          : data['createdAt'],
      'audio_url': data['audioUrl'],
      'is_pending_analysis': data['isPending'] == true ? 1 : 0,
      'analysis_json': data['analysis'] != null
          ? jsonEncode(data['analysis'])
          : null,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> upsertFromRemote(Map<String, dynamic> data) async {
    final analysis = data['analysis'];
    await _db.insertJournal({
      'id': data['id'],
      'content': data['content'] ?? '',
      'title': data['topic']?['title'] ?? 'Free Write',
      'created_at': DateTime.parse(data['createdAt']).millisecondsSinceEpoch,
      'audio_url': data['audioUrl'],
      'is_pending_analysis': analysis == null ? 0 : 0,
      'analysis_json': analysis != null ? jsonEncode(analysis) : null,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteJournal(String id) async {
    final db = await _db.database;
    await db.delete('journals', where: 'id = ?', whereArgs: [id]);
  }

  Stream<List<JournalEntry>> watchJournals() {
    return _db.watchAllJournals().map(
      (journals) => journals.map((map) => _journalFromDb(map)).toList(),
    );
  }

  JournalEntry _journalFromDb(Map<String, dynamic> map) {
    Analysis? analysis;
    if (map['analysis_json'] != null) {
      try {
        final analysisData = jsonDecode(map['analysis_json'] as String);
        analysis = Analysis.fromJson(analysisData);
      } catch (e) {
        // Failed to parse analysis JSON
      }
    }

    return JournalEntry(
      id: map['id'] as String,
      content: map['content'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      audioUrl: map['audio_url'] as String?,
      analysis: analysis,
      isPending: (map['is_pending_analysis'] as int?) == 1,
    );
  }
}

final journalLocalDataSourceProvider = Provider<JournalLocalDataSource>((ref) {
  return JournalLocalDataSource(ref.watch(databaseProvider));
});
