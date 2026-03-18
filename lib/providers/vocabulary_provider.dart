import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vocabulary_service.dart';
export '../services/vocabulary_service.dart' show VocabularyCounts;

final vocabularyStreamProvider = StreamProvider<Map<String, String>>((ref) {
  final service = ref.watch(vocabularyServiceProvider);
  return service.watchVocabulary();
});

class VocabularyData {
  final Map<String, String> items;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final VocabularyCounts counts;
  final bool isLoading;
  final bool hasMore;

  VocabularyData({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.counts,
    this.isLoading = false,
    this.hasMore = false,
  });

  VocabularyData copyWith({
    Map<String, String>? items,
    int? totalCount,
    int? totalPages,
    int? currentPage,
    VocabularyCounts? counts,
    bool? isLoading,
    bool? hasMore,
  }) {
    return VocabularyData(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      counts: counts ?? this.counts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class VocabularyNotifier
    extends StateNotifier<AsyncValue<Map<String, String>>> {
  final VocabularyService _service;

  VocabularyNotifier(this._service) : super(const AsyncValue.loading());

  Stream<Map<String, String>> watchVocabulary() {
    return _service.watchVocabulary();
  }

  Future<void> loadVocabulary(String language) async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final vocab = await _service.getVocabulary(language);
      state = AsyncValue.data(vocab);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Map<String, String>> getVocabulary(String language) async {
    if (state.hasValue && state.value != null) {
      return state.value!;
    }
    await loadVocabulary(language);
    return state.value ?? {};
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
      await _service.updateStatus(wordLower, statusLower, language);
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
      await _service.markBatchKnown(lowerWords, language);
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
      await _service.deleteWord(wordLower, language);
    } catch (e) {
      state = AsyncValue.data(currentMap);
    }
  }
}

final vocabularyProvider =
    StateNotifierProvider<VocabularyNotifier, AsyncValue<Map<String, String>>>((
      ref,
    ) {
      return VocabularyNotifier(ref.watch(vocabularyServiceProvider));
    });

class PaginatedVocabularyNotifier extends StateNotifier<VocabularyData> {
  final VocabularyService _service;
  final Ref _ref;
  String? _currentLanguage;

  PaginatedVocabularyNotifier(this._service, this._ref)
    : super(
        VocabularyData(
          items: {},
          totalCount: 0,
          totalPages: 0,
          currentPage: 1,
          counts: VocabularyCounts(total: 0, known: 0, learning: 0, unknown: 0),
          isLoading: true,
        ),
      );

  Future<void> loadVocabulary(String language) async {
    _currentLanguage = language;
    state = state.copyWith(isLoading: true);

    try {
      final result = await _service.getVocabularyPage(language, page: 1);
      state = VocabularyData(
        items: result.items,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        currentPage: result.currentPage,
        counts: result.counts,
        isLoading: false,
        hasMore: result.currentPage < result.totalPages,
      );
    } catch (e, st) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || _currentLanguage == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final result = await _service.getVocabularyPage(
        _currentLanguage!,
        page: state.currentPage + 1,
      );

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

    state = state.copyWith(items: newItems, counts: newCounts);

    try {
      await _service.updateStatus(wordLower, statusLower, language);
    } catch (e) {
      // Revert on error
      final revertedItems = Map<String, String>.from(state.items)
        ..remove(wordLower);
      state = state.copyWith(items: revertedItems, counts: state.counts);
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

    state = state.copyWith(items: newItems, counts: newCounts);

    try {
      await _service.deleteWord(wordLower, language);
    } catch (e) {
      // Revert on error
      final revertedItems = Map<String, String>.from(state.items)
        ..[wordLower] = removedStatus ?? '';
      state = state.copyWith(items: revertedItems, counts: state.counts);
    }
  }
}

final paginatedVocabularyProvider =
    StateNotifierProvider<PaginatedVocabularyNotifier, VocabularyData>((ref) {
      return PaginatedVocabularyNotifier(
        ref.watch(vocabularyServiceProvider),
        ref,
      );
    });
