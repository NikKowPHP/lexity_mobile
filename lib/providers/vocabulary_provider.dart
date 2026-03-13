import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vocabulary_service.dart';

class VocabularyNotifier extends StateNotifier<AsyncValue<Map<String, String>>> {
  final VocabularyService _service;
  
  VocabularyNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadVocabulary(String language) async {
    state = const AsyncValue.loading();
    try {
      final vocab = await _service.getVocabulary(language);
      state = AsyncValue.data(vocab);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateWordStatus(String word, String status, String language) async {
    final currentMap = state.value ?? {};
    final wordLower = word.toLowerCase();
    final statusLower = status.toLowerCase();
    
    final newMap = Map<String, String>.from(currentMap)..[wordLower] = statusLower;
    state = AsyncValue.data(newMap);

    try {
      await _service.updateStatus(wordLower, statusLower, language);
    } catch (e) {
      // Rollback to previous state on error to keep UI consistent with reality
      state = AsyncValue.data(currentMap);
    }
  }

  Future<void> markBatchKnown(List<String> words, String language) async {
    final currentMap = state.value ?? {};
    final newMap = Map<String, String>.from(currentMap);
    final lowerWords = words.map((w) => w.toLowerCase()).toList();
    for (var w in lowerWords) {
      newMap[w] = 'known';
    }
    state = AsyncValue.data(newMap);

    try {
      await _service.markBatchKnown(lowerWords, language);
    } catch (e) {
      state = AsyncValue.data(currentMap); // Rollback
    }
  }
}

final vocabularyProvider = StateNotifierProvider<VocabularyNotifier, AsyncValue<Map<String, String>>>((ref) {
  return VocabularyNotifier(ref.watch(vocabularyServiceProvider));
});
