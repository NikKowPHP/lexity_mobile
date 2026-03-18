import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import '../database/app_database.dart';
import 'user_provider.dart';

JournalEntry _journalFromDb(Map<String, dynamic> map) {
  return JournalEntry(
    id: map['id'] as String,
    content: map['content'] as String? ?? '',
    title: map['title'] as String? ?? 'Free Write',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    audioUrl: map['audio_url'] as String?,
    isPending: (map['is_pending_analysis'] as int?) == 1,
    analysis: map['analysis_json'] != null
        ? Analysis.fromJson(jsonDecode(map['analysis_json'] as String))
        : null,
  );
}

final journalHistoryStreamProvider =
    StreamProvider.autoDispose<List<JournalEntry>>((ref) {
      final db = ref.watch(databaseProvider);
      return db.watchAllJournals().map(
        (journals) => journals.map((map) => _journalFromDb(map)).toList(),
      );
    });

final journalHistoryProvider = journalHistoryStreamProvider;

final journalDetailProvider = FutureProvider.autoDispose
    .family<JournalEntry, String>((ref, id) async {
      final db = ref.watch(databaseProvider);
      final journal = await db.getJournalById(id);
      if (journal == null) {
        throw Exception('Journal not found');
      }
      return _journalFromDb(journal);
    });

final suggestedTopicsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final service = ref.watch(journalServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.getSuggestedTopics(activeLang);
});

class JournalNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<String?> createEntry(
    String title,
    String content,
    String language, {
    String? moduleId,
  }) async {
    final service = ref.read(journalServiceProvider);
    state = const AsyncValue.loading();
    try {
      final entry = await service.createEntry(
        content,
        title,
        language,
        moduleId: moduleId,
      );
      state = const AsyncValue.data(null);
      return entry.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> createAudioEntry(
    String filePath,
    String language, {
    String? moduleId,
  }) async {
    final service = ref.read(journalServiceProvider);
    state = const AsyncValue.loading();
    try {
      await service.createAudioEntry(filePath, language, moduleId: moduleId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      final service = ref.read(journalServiceProvider);
      await service.deleteEntry(id);
    } catch (e) {}
  }

  Future<void> refreshTopics(String language) async {
    final service = ref.read(journalServiceProvider);
    await service.generateTopics(language);
  }
}

final journalNotifierProvider =
    NotifierProvider<JournalNotifier, AsyncValue<void>>(() {
      return JournalNotifier();
    });
