import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/srs_item.dart';
import '../services/srs_service.dart';

class SrsState {
  final List<SrsItem> deck;
  final List<SrsItem> allItems;
  final bool isLoading;
  final String? error;

  SrsState({
    this.deck = const [],
    this.allItems = const [],
    this.isLoading = false,
    this.error,
  });

  SrsItem? get currentCard => deck.isNotEmpty ? deck.first : null;

  SrsState copyWith({
    List<SrsItem>? deck,
    List<SrsItem>? allItems,
    bool? isLoading,
    String? error,
  }) {
    return SrsState(
      deck: deck ?? this.deck,
      allItems: allItems ?? this.allItems,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class SrsNotifier extends StateNotifier<SrsState> {
  final SrsService _service;
  SrsNotifier(this._service) : super(SrsState());

  Stream<List<SrsItem>> watchDeck() {
    return _service.watchDueSrsItems();
  }

  Future<void> loadDeck(String language) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deck = await _service.fetchDeck(language);
      state = state.copyWith(deck: deck, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadAllItems(String language) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _service.fetchAllItems(language);
      state = state.copyWith(allItems: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> deleteItem(String id, String language) async {
    try {
      await _service.deleteItem(id);
      loadDeck(language);
      final updatedDeck = state.deck.where((item) => item.id != id).toList();
      state = state.copyWith(deck: updatedDeck);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete flashcard');
    }
  }

  Future<void> answerCard(int quality) async {
    final card = state.currentCard;
    if (card == null) return;

    final updatedDeck = List<SrsItem>.from(state.deck)..removeAt(0);
    state = state.copyWith(deck: updatedDeck);

    try {
      await _service.reviewItem(card.id, quality);
    } catch (e) {
      // Handle error
    }
  }

  Future<bool> addToDeckFromTranslation({
    required String front,
    required String back,
    required String language,
    String? explanation,
  }) async {
    try {
      await _service.createFromTranslation(
        front: front,
        back: back,
        language: language,
        explanation: explanation,
      );
      loadDeck(language);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> loadDrill(String language) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deck = await _service.fetchDrillItems(language);
      state = state.copyWith(deck: deck, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final srsProvider = StateNotifierProvider<SrsNotifier, SrsState>((ref) {
  return SrsNotifier(ref.watch(srsServiceProvider));
});

final srsDeckStreamProvider = StreamProvider<List<SrsItem>>((ref) {
  final service = ref.watch(srsServiceProvider);
  return service.watchDueSrsItems();
});
