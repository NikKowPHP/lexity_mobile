import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'journal_provider.dart';

enum OnboardingStep { profileSetup, firstJournal, viewAnalysis, studyIntro, completed, inactive }

class OnboardingNotifier extends StateNotifier<OnboardingStep> {
  final Ref ref;
  OnboardingNotifier(this.ref) : super(OnboardingStep.inactive) {
    // Determine initial step when provider is first accessed
    determineStep();
  }

  void determineStep() {
    final profileAsync = ref.read(userProfileProvider);
    final journalsAsync = ref.read(journalHistoryProvider);
    
    // If either is still loading, we can't decide yet
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
      state = OnboardingStep.viewAnalysis; // Need to see analysis which usually generates cards
    } else {
      state = OnboardingStep.studyIntro;
    }
  }
}

final StateNotifierProvider<OnboardingNotifier, OnboardingStep> onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingStep>((ref) {
  // Listen to profile and journal changes to update onboarding state
  ref.listen(userProfileProvider, (previous, next) {
     ref.read(onboardingProvider.notifier).determineStep();
  });
  ref.listen(journalHistoryProvider, (previous, next) {
     ref.read(onboardingProvider.notifier).determineStep();
  });
  
  return OnboardingNotifier(ref);
});
