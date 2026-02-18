import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final UserService _service;
  UserProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.fetchProfile());
  }

  // Updated to handle all profile fields
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

    // Optimistic UI
    state = AsyncValue.data(updated);
    
    try {
      await _service.updateProfile(updated);
    } catch (e) {
      state = AsyncValue.data(current); // Rollback
      // In a real app, handle error display via a separate error state or callback
    }
  }
  
  // New method to add a language
  Future<void> addLanguage(String newLanguage) async {
    final current = state.value;
    if (current == null) return;
    
    try {
       // We don't do full optimistic update here because we need the backend 
       // to confirm the creation of the language profile record
       final updatedProfile = await _service.addLanguage(newLanguage);
       state = AsyncValue.data(updatedProfile);
    } catch (e) {
       // Handle error
    }
  }
  Future<void> updateGoals(UserGoals goals) async {
    final current = state.value;
    if (current == null) return;

    // Optimistic update
    final updatedProfile = current.copyWith(goals: goals);
    state = AsyncValue.data(updatedProfile);

    try {
      await _service.updateGoals(goals);
      // We can optionally refresh from server here to ensure sync
    } catch (e) {
      state = AsyncValue.data(current); // Rollback
    }
  }

  Future<String?> getManageSubscriptionUrl() async {
    try {
      return await _service.getBillingPortalUrl();
    } catch (e) {
      return null;
    }
  }

  Future<void> resetOnboarding() async {
    await _service.resetOnboarding();
    await refresh(); // Reload profile to reflect un-onboarded state
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return UserProfileNotifier(ref.watch(userServiceProvider));
});
