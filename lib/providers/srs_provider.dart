import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/srs_item.dart';
import '../data/repositories/srs_repository.dart';

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

class SrsNotifier extends Notifier<SrsState> {
  @override
  SrsState build() {
    return SrsState();
  }

  Stream<List<SrsItem>> watchDeck() {
    return ref.read(srsRepositoryProvider).watchDueSrsItems();
  }

  Future<void> loadDeck(String language) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // fetchDeck now returns local data immediately and syncs in background
      final deck = await ref.read(srsRepositoryProvider).fetchDeck(language);
      state = state.copyWith(deck: deck, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadAllItems(String language) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // fetchAllItems now returns local data immediately and syncs in background
      final items = await ref
          .read(srsRepositoryProvider)
          .fetchAllItems(language);
      state = state.copyWith(allItems: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> deleteItem(String id, String language) async {
    try {
      await ref.read(srsRepositoryProvider).deleteItem(id);
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
      await ref.read(srsRepositoryProvider).reviewItem(card.id, quality);
    } catch (e) {}
  }

  Future<bool> addToDeckFromTranslation({
    required String front,
    required String back,
    required String language,
    String? explanation,
  }) async {
    try {
      await ref
          .read(srsRepositoryProvider)
          .createFromTranslation(
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
      final deck = await ref
          .read(srsRepositoryProvider)
          .fetchDrillItems(language);
      state = state.copyWith(deck: deck, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final srsProvider = NotifierProvider<SrsNotifier, SrsState>(() {
  return SrsNotifier();
});

final srsDeckStreamProvider = StreamProvider<List<SrsItem>>((ref) {
  final service = ref.watch(srsRepositoryProvider);
  return service.watchDueSrsItems();
});
