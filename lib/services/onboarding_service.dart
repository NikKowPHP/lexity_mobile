import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/network/api_client.dart';
import 'package:lexity_mobile/services/logger_service.dart';
import '../models/onboarding_data.dart';

class OnboardingService {
  final ApiClient _client;
  final Ref _ref;
  late final LoggerService _logger;

  OnboardingService(this._client, this._ref) {
    _logger = _ref.read(loggerProvider);
  }

  Future<void> submitOnboarding(OnboardingData data) async {
    _logger.info('OnboardingService: Submitting onboarding data');
    try {
      final response = await _client.post(
        '/api/user/onboard',
        data: data.toJson(),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to submit onboarding data');
      }
      _logger.info('OnboardingService: Onboarding data submitted successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'OnboardingService: Error submitting onboarding',
        e,
        stackTrace,
      );
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
  return OnboardingService(ref.watch(apiClientProvider), ref);
});
