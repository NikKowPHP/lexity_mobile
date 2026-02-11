import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';

// 1. Manages the full User Object
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final UserService _service;
  UserProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.fetchProfile());
  }

  Future<void> updateInfo({String? lang, String? style}) async {
    final current = state.value;
    if (current == null) return;

    final updated = UserProfile(
      id: current.id,
      email: current.email,
      defaultTargetLanguage: lang ?? current.defaultTargetLanguage,
      writingStyle: style ?? current.writingStyle,
      nativeLanguage: current.nativeLanguage,
      subscriptionTier: current.subscriptionTier,
    );

    final previousState = state;
    state = AsyncValue.data(updated); // Optimistic UI
    
    try {
      await _service.updateProfile(updated);
    } catch (e) {
      state = previousState; // Rollback on error
    }
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return UserProfileNotifier(ref.watch(userServiceProvider));
});

// 2. Global "Active Language" provider that other screens watch
final activeLanguageProvider = Provider<String>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) => p.defaultTargetLanguage,
    orElse: () => 'Spanish', // Fallback
  );
});
