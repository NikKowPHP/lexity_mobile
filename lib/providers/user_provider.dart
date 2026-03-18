import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';

class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    return await ref.read(userServiceProvider).fetchProfile();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(userServiceProvider).fetchProfile(),
    );
  }

  Future<void> updateInfo({
    String? nativeLanguage,
    String? targetLanguage,
    String? writingStyle,
    String? writingPurpose,
    String? selfAssessedLevel,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(
      nativeLanguage: nativeLanguage,
      defaultTargetLanguage: targetLanguage,
      writingStyle: writingStyle,
      writingPurpose: writingPurpose,
      selfAssessedLevel: selfAssessedLevel,
    );

    state = AsyncValue.data(updated);

    try {
      await ref.read(userServiceProvider).updateProfile(updated);
    } catch (e) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> addLanguage(String newLanguage) async {
    final current = state.value;
    if (current == null) return;

    try {
      final updatedProfile = await ref
          .read(userServiceProvider)
          .addLanguage(newLanguage);
      state = AsyncValue.data(updatedProfile);
    } catch (e) {}
  }

  Future<void> updateGoals(UserGoals goals) async {
    final current = state.value;
    if (current == null) return;

    final updatedProfile = current.copyWith(goals: goals);
    state = AsyncValue.data(updatedProfile);

    try {
      await ref.read(userServiceProvider).updateGoals(goals);
    } catch (e) {
      state = AsyncValue.data(current);
    }
  }

  Future<String?> getManageSubscriptionUrl() async {
    try {
      return await ref.read(userServiceProvider).getBillingPortalUrl();
    } catch (e) {
      return null;
    }
  }

  Future<void> resetOnboarding() async {
    await ref.read(userServiceProvider).resetOnboarding();
    await refresh();
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile>(() {
      return UserProfileNotifier();
    });

final activeLanguageProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).value?.defaultTargetLanguage ?? 'es';
});
