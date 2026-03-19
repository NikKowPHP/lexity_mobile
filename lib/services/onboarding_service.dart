import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/network/api_client.dart';
import 'package:lexity_mobile/services/logger_service.dart';
import 'package:lexity_mobile/database/app_database.dart';
import 'package:lexity_mobile/database/repositories/sync_repository.dart';
import 'package:lexity_mobile/providers/connectivity_provider.dart';
import '../models/onboarding_data.dart';

class OnboardingService {
  final ApiClient _client;
  final AppDatabase _db;
  final SyncRepository _syncRepo;
  final Ref _ref;
  late final LoggerService _logger;

  OnboardingService(this._client, this._db, this._syncRepo, this._ref) {
    _logger = _ref.read(loggerProvider);
  }

  Future<void> submitOnboarding(OnboardingData data) async {
    _logger.info('OnboardingService: Saving onboarding data locally-first');

    try {
      // 1. Get current user from DB to preserve fields like email/id
      final localUsers = await _db.getAllUsers();
      if (localUsers.isNotEmpty) {
        final currentUser = localUsers.first;

        // 2. Update the local users table immediately
        final updatedData = {
          ...currentUser,
          'nativeLanguage': data.nativeLanguage,
          'defaultTargetLanguage': data.targetLanguage,
          'writingStyle': data.writingStyle,
          'writingPurpose': data.writingPurpose,
          'selfAssessedLevel': data.selfAssessedLevel,
        };
        await _db.insertUser(updatedData);
        _logger.info('OnboardingService: Local user data saved');
      }

      // 3. Queue for synchronization
      await _syncRepo.enqueueProfileUpdate(data.toJson());
      _logger.info('OnboardingService: Profile update queued for sync');

      // 4. Trigger immediate sync if online (fire and forget)
      final isOnline = _ref.read(connectivityProvider);
      if (isOnline) {
        try {
          await _client.post('/api/user/onboard', data: data.toJson());
        } catch (e) {
          _logger.warning(
              'Onboarding background push failed, sync queue will retry.');
        }
      }

      _logger.info('OnboardingService: Local save and sync-queue complete');
    } catch (e, stackTrace) {
      _logger.error(
          'OnboardingService: Error in local-first save', e, stackTrace);
      rethrow;
    }
  }

  Future<void> completeOnboarding() async {
    _logger.info('OnboardingService: Completing onboarding');
    try {
      final response = await _client.post('/api/user/complete-onboarding');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to complete onboarding');
      }
      _logger.info('OnboardingService: Onboarding completed');
    } catch (e, stackTrace) {
      _logger.error(
        'OnboardingService: Error completing onboarding',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
    ref.watch(syncRepositoryProvider),
    ref,
  );
});
