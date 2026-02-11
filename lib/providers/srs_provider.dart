import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/srs_item.dart';
import '../services/srs_service.dart';

class SrsState {
  final List<SrsItem> deck;
  final bool isLoading;
  final String? error;

  SrsState({this.deck = const [], this.isLoading = false, this.error});

  SrsItem? get currentCard => deck.isNotEmpty ? deck.first : null;
}

class SrsNotifier extends StateNotifier<SrsState> {
  final SrsService _service;
  SrsNotifier(this._service) : super(SrsState());

  Future<void> loadDeck(String language) async {
    state = SrsState(isLoading: true);
    try {
      final deck = await _service.fetchDeck(language);
      state = SrsState(deck: deck, isLoading: false);
    } catch (e) {
      state = SrsState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> answerCard(int quality) async {
    final card = state.currentCard;
    if (card == null) return;

    // 1. Optimistic UI: Remove card from list immediately
    final updatedDeck = List<SrsItem>.from(state.deck)..removeAt(0);
    state = SrsState(deck: updatedDeck);

    // 2. Background Sync
    try {
      await _service.reviewItem(card.id, quality);
    } catch (e) {
      // Handle error (optionally re-add card to deck)
    }
  }
}

final srsProvider = StateNotifierProvider<SrsNotifier, SrsState>((ref) {
  return SrsNotifier(ref.watch(srsServiceProvider));
});
