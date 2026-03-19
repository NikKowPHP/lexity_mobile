import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/onboarding_data.dart';
import '../services/onboarding_service.dart';
import 'user_provider.dart';
import 'journal_provider.dart';
import '../services/logger_service.dart';

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

  // Call this after user completes language setup (Step 1)
  Future<void> completeLanguageSetup(OnboardingData data) async {
    try {
      final onboardingService = ref.read(onboardingServiceProvider);
      await onboardingService.submitOnboarding(data);
      // Invalidate user profile to refresh data
      ref.invalidate(userProfileProvider);
      determineStep();
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('OnboardingNotifier: Failed to submit language setup', e);
      rethrow;
    }
  }

  // Call this after user finishes onboarding (Step 4 - skip goals)
  Future<void> finishOnboarding() async {
    try {
      final onboardingService = ref.read(onboardingServiceProvider);
      await onboardingService.completeOnboarding();
      ref.invalidate(userProfileProvider);
      determineStep();
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('OnboardingNotifier: Failed to complete onboarding', e);
      rethrow;
    }
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingStep>(
  () {
    return OnboardingNotifier();
  },
);
