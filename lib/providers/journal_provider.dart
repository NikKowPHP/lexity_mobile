import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import 'user_provider.dart';

final journalHistoryProvider = FutureProvider.autoDispose<List<JournalEntry>>((ref) async {
  final service = ref.watch(journalServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.getHistory(activeLang);
});

final journalDetailProvider = FutureProvider.autoDispose.family<JournalEntry, String>((ref, id) async {
  final service = ref.watch(journalServiceProvider);
  return service.getEntry(id);
});

final suggestedTopicsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final service = ref.watch(journalServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.getSuggestedTopics(activeLang);
});

class JournalNotifier extends StateNotifier<AsyncValue<void>> {
  final JournalService _service;
  final Ref _ref;

  JournalNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  // Update signature to accept optional moduleId
  // CHANGE: Return Future<String?> instead of Future<void>
  Future<String?> createEntry(
    String title,
    String content,
    String language, {
    String? moduleId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // 1. Create the entry
      final entry = await _service.createEntry(
        content,
        title,
        language,
        moduleId: moduleId,
      );
      
      // 2. Trigger Analysis
      await _service.analyzeEntry(entry.id);
      
      // 3. Refresh lists
      _ref.invalidate(journalHistoryProvider);
      state = const AsyncValue.data(null);
      
      // 4. Return the ID
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
    state = const AsyncValue.loading();
    try {
      final entry = await _service.createAudioEntry(
        filePath,
        language,
        moduleId: moduleId,
      );
      // Auto-analyze
      await _service.analyzeEntry(entry.id);
      _ref.invalidate(journalHistoryProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _service.deleteEntry(id);
      _ref.invalidate(journalHistoryProvider);
    } catch (e) {
      // handle error
    }
  }
  
  Future<void> refreshTopics(String language) async {
     await _service.generateTopics(language);
     _ref.invalidate(suggestedTopicsProvider);
  }
}

final journalNotifierProvider = StateNotifierProvider<JournalNotifier, AsyncValue<void>>((ref) {
  return JournalNotifier(ref.watch(journalServiceProvider), ref);
});
