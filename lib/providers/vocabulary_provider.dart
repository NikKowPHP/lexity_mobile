import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vocabulary_service.dart';
export '../services/vocabulary_service.dart' show VocabularyCounts;

final vocabularyStreamProvider = StreamProvider<Map<String, String>>((ref) {
  final service = ref.watch(vocabularyServiceProvider);
  return service.watchVocabulary();
});

class VocabularyData {
  final Map<String, String> items;
  final Map<String, String>? delta; // NEW FIELD
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final VocabularyCounts counts;
  final bool isLoading;
  final bool hasMore;

  VocabularyData({
    required this.items,
    this.delta, // ADDED
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.counts,
    this.isLoading = false,
    this.hasMore = false,
  });

  VocabularyData copyWith({
    Map<String, String>? items,
    Map<String, String>? delta, // ADDED
    int? totalCount,
    int? totalPages,
    int? currentPage,
    VocabularyCounts? counts,
    bool? isLoading,
    bool? hasMore,
  }) {
    return VocabularyData(
      items: items ?? this.items,
      delta: delta, // Clear delta if not provided
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      counts: counts ?? this.counts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class VocabularyNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    return await ref.read(vocabularyServiceProvider).getVocabulary('es');
  }

  Stream<Map<String, String>> watchVocabulary() {
    return ref.read(vocabularyServiceProvider).watchVocabulary();
  }

  Future<void> loadVocabulary(String language) async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final vocab = await ref
          .read(vocabularyServiceProvider)
          .getVocabulary(language);
      state = AsyncValue.data(vocab);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Map<String, String>> getVocabulary(String language) async {
    await loadVocabulary(language);
    return state.value ?? {};
  }

  Future<void> preloadVocabularyForLanguages(List<String> languages) async {
    for (final language in languages) {
      try {
        final vocab = await ref
            .read(vocabularyServiceProvider)
            .getVocabulary(language);
        final currentMap = state.value ?? {};
        final newMap = Map<String, String>.from(currentMap)..addAll(vocab);
        state = AsyncValue.data(newMap);
      } catch (e) {}
    }
  }

  Future<void> updateWordStatus(
    String word,
    String status,
    String language,
  ) async {
    final currentMap = state.value ?? {};
    final wordLower = word.toLowerCase();
    final statusLower = status.toLowerCase();

    final newMap = Map<String, String>.from(currentMap)
      ..[wordLower] = statusLower;
    state = AsyncValue.data(newMap);

    try {
      await ref
          .read(vocabularyServiceProvider)
          .updateStatus(wordLower, statusLower, language);
    } catch (e) {
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
      await ref
          .read(vocabularyServiceProvider)
          .markBatchKnown(lowerWords, language);
    } catch (e) {
      state = AsyncValue.data(currentMap);
    }
  }

  Future<void> deleteWord(String word, String language) async {
    final currentMap = state.value ?? {};
    final wordLower = word.toLowerCase();

    final newMap = Map<String, String>.from(currentMap)..remove(wordLower);
    state = AsyncValue.data(newMap);

    try {
      await ref.read(vocabularyServiceProvider).deleteWord(wordLower, language);
    } catch (e) {
      state = AsyncValue.data(currentMap);
    }
  }
}

final vocabularyProvider =
    AsyncNotifierProvider<VocabularyNotifier, Map<String, String>>(() {
      return VocabularyNotifier();
    });

class PaginatedVocabularyNotifier extends Notifier<VocabularyData> {
  String? _currentLanguage;

  @override
  VocabularyData build() {
    return VocabularyData(
      items: {},
      totalCount: 0,
      totalPages: 0,
      currentPage: 1,
      counts: VocabularyCounts(total: 0, known: 0, learning: 0, unknown: 0),
      isLoading: true,
    );
  }

  Future<void> loadVocabulary(String language) async {
    _currentLanguage = language;
    state = state.copyWith(isLoading: true);

    try {
      final result = await ref
          .read(vocabularyServiceProvider)
          .getVocabularyPage(language, page: 1);
      state = VocabularyData(
        items: result.items,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        currentPage: result.currentPage,
        counts: result.counts,
        isLoading: false,
        hasMore: result.currentPage < result.totalPages,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || _currentLanguage == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final result = await ref
          .read(vocabularyServiceProvider)
          .getVocabularyPage(_currentLanguage!, page: state.currentPage + 1);

      final newItems = Map<String, String>.from(state.items)
        ..addAll(result.items);

      state = VocabularyData(
        items: newItems,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        currentPage: result.currentPage,
        counts: result.counts,
        isLoading: false,
        hasMore: result.currentPage < result.totalPages,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateWordStatus(
    String word,
    String status,
    String language,
  ) async {
    final wordLower = word.toLowerCase();
    final statusLower = status.toLowerCase();

    final newItems = Map<String, String>.from(state.items)
      ..[wordLower] = statusLower;

    final newCounts = VocabularyCounts(
      total: state.counts.total,
      known: statusLower == 'known'
          ? state.counts.known + 1
          : state.counts.known,
      learning: statusLower == 'learning'
          ? state.counts.learning + 1
          : state.counts.learning,
      unknown: statusLower == 'unknown'
          ? state.counts.unknown + 1
          : state.counts.unknown,
    );

    final delta = {wordLower: statusLower};
    state = state.copyWith(items: newItems, counts: newCounts, delta: delta);

    try {
      await ref
          .read(vocabularyServiceProvider)
          .updateStatus(wordLower, statusLower, language);
    } catch (e) {
      final revertedItems = Map<String, String>.from(state.items)
        ..remove(wordLower);
      state = state.copyWith(items: revertedItems, counts: state.counts, delta: null);
    }
  }

  Future<void> deleteWord(String word, String language) async {
    final wordLower = word.toLowerCase();
    final removedStatus = state.items[wordLower];

    final newItems = Map<String, String>.from(state.items)..remove(wordLower);

    final newCounts = VocabularyCounts(
      total: state.counts.total - 1,
      known: removedStatus == 'known'
          ? state.counts.known - 1
          : state.counts.known,
      learning: removedStatus == 'learning'
          ? state.counts.learning - 1
          : state.counts.learning,
      unknown: removedStatus == 'unknown'
          ? state.counts.unknown - 1
          : state.counts.unknown,
    );

    final delta = {wordLower: ''}; // Empty string indicates removal
    state = state.copyWith(items: newItems, counts: newCounts, delta: delta);

    try {
      await ref.read(vocabularyServiceProvider).deleteWord(wordLower, language);
    } catch (e) {
      final revertedItems = Map<String, String>.from(state.items)
        ..[wordLower] = removedStatus ?? '';
      state = state.copyWith(items: revertedItems, counts: state.counts, delta: null);
    }
  }
}

final paginatedVocabularyProvider =
    NotifierProvider<PaginatedVocabularyNotifier, VocabularyData>(() {
      return PaginatedVocabularyNotifier();
    });
