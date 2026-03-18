import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'journal_provider.dart';

enum OnboardingStep {
  profileSetup,
  firstJournal,
  viewAnalysis,
  studyIntro,
  completed,
  inactive,
}

class OnboardingNotifier extends Notifier<OnboardingStep> {
  @override
  OnboardingStep build() {
    ref.listen(userProfileProvider, (previous, next) {
      determineStep();
    });
    ref.listen(journalHistoryProvider, (previous, next) {
      determineStep();
    });

    determineStep();
    return OnboardingStep.inactive;
  }

  void determineStep() {
    final profileAsync = ref.read(userProfileProvider);
    final journalsAsync = ref.read(journalHistoryProvider);

    if (profileAsync.isLoading || journalsAsync.isLoading) return;

    final profile = profileAsync.value;
    final journals = journalsAsync.value ?? [];

    if (profile == null) {
      state = OnboardingStep.inactive;
      return;
    }

    if (profile.onboardingCompleted) {
      state = OnboardingStep.completed;
      return;
    }

    if (profile.nativeLanguage == null || profile.nativeLanguage!.isEmpty) {
      state = OnboardingStep.profileSetup;
    } else if (journals.isEmpty) {
      state = OnboardingStep.firstJournal;
    } else if (journals.first.analysis == null) {
      state = OnboardingStep.viewAnalysis;
    } else if (profile.srsCount == 0) {
      state = OnboardingStep.viewAnalysis;
    } else {
      state = OnboardingStep.studyIntro;
    }
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingStep>(
  () {
    return OnboardingNotifier();
  },
);
