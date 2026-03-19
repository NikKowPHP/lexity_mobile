import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/translation_result.dart';
import '../services/translation_service.dart';

class TranslatorState {
  final String fullTranslation;
  final List<TranslationSegment> segments;
  final bool isTranslating;
  final bool isBreakingDown;

  TranslatorState({
    this.fullTranslation = '',
    this.segments = const [],
    this.isTranslating = false,
    this.isBreakingDown = false,
  });

  TranslatorState copyWith({
    String? fullTranslation,
    List<TranslationSegment>? segments,
    bool? isTranslating,
    bool? isBreakingDown,
  }) {
    return TranslatorState(
      fullTranslation: fullTranslation ?? this.fullTranslation,
      segments: segments ?? this.segments,
      isTranslating: isTranslating ?? this.isTranslating,
      isBreakingDown: isBreakingDown ?? this.isBreakingDown,
    );
  }
}

class TranslatorNotifier extends Notifier<TranslatorState> {
  @override
  TranslatorState build() {
    return TranslatorState();
  }

  Future<void> runTranslation(String text, String source, String target) async {
    state = TranslatorState(isTranslating: true, isBreakingDown: true);

    try {
      final translationService = ref.read(translationServiceProvider);
      final fastResult = await translationService.translate(
        text,
        source,
        target,
      );
      state = state.copyWith(fullTranslation: fastResult, isTranslating: false);

      final segments = await translationService.translateBreakdown(
        text,
        source,
        target,
      );
      state = state.copyWith(segments: segments, isBreakingDown: false);
    } catch (e) {
      state = state.copyWith(isTranslating: false, isBreakingDown: false);
    }
  }
}

final translatorProvider =
    NotifierProvider<TranslatorNotifier, TranslatorState>(() {
      return TranslatorNotifier();
    });
