import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/network/api_client.dart';
import '../models/user_profile.dart';
import 'logger_service.dart';
import '../providers/connectivity_provider.dart';
import '../database/app_database.dart';

class UserService {
  final ApiClient _client;
  final Ref _ref;
  late final LoggerService _logger;

  UserService(this._client, this._ref) {
    _logger = _ref.read(loggerProvider);
  }

  Future<UserProfile> fetchProfile() async {
    _logger.info('UserService: Fetching user profile');

    final isOnline = _ref.read(connectivityProvider);
    final db = _ref.read(databaseProvider);

    if (!isOnline) {
      _logger.info('UserService: Offline, trying cache');
      final localUsers = await db.getAllUsers();
      if (localUsers.isNotEmpty) {
        _logger.info('UserService: Returning cached profile from DB');
        return UserProfile.fromJson(localUsers.first);
      }
      throw Exception('No cached profile available offline');
    }

    try {
      final response = await _client.get('/api/user/profile');

      _logger.debug(
        'UserService: fetchProfile response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await db.insertUser(data);
        _logger.info('UserService: Profile fetched and cached successfully');
        return UserProfile.fromJson(data);
      }

      if (response.statusCode == 401) {
        _logger.warning('UserService: Unauthorized, falling back to cache');
        final localUsers = await db.getAllUsers();
        if (localUsers.isNotEmpty) {
          return UserProfile.fromJson(localUsers.first);
        }
        throw Exception('Unauthorized - please log in again');
      }

      final errorMsg = response.data['error'] ?? 'Failed to load profile';
      _logger.warning('UserService: Profile fetch failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      _logger.warning('UserService: API failed, trying cache: $e');
      final localUsers = await db.getAllUsers();
      if (localUsers.isNotEmpty) {
        return UserProfile.fromJson(localUsers.first);
      }
      rethrow;
    }
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    _logger.info('UserService: Updating user profile');
    try {
      final body = {
        'nativeLanguage': profile.nativeLanguage,
        'targetLanguage': profile.defaultTargetLanguage,
        'writingStyle': profile.writingStyle,
        'writingPurpose': profile.writingPurpose,
        'selfAssessedLevel': profile.selfAssessedLevel,
      };

      final response = await _client.put('/api/user/profile', data: body);

      _logger.debug(
        'UserService: updateProfile response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return UserProfile.fromJson(data);
      }

      throw Exception('Failed to update profile');
    } catch (e, stackTrace) {
      _logger.error('UserService: Error during updateProfile', e, stackTrace);
      rethrow;
    }
  }

  Future<UserProfile> addLanguage(String newLanguage) async {
    _logger.info('UserService: Adding new language: $newLanguage');
    try {
      final response = await _client.put(
        '/api/user/profile',
        data: {'newTargetLanguage': newLanguage},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return UserProfile.fromJson(data);
      }
      throw Exception('Failed to add language');
    } catch (e, st) {
      _logger.error('UserService: Error adding language', e, st);
      rethrow;
    }
  }

  Future<void> updateGoals(UserGoals goals) async {
    _logger.info('UserService: Updating user goals');
    try {
      final response = await _client.put(
        '/api/user/goals',
        data: goals.toJson(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update goals');
      }
    } catch (e, st) {
      _logger.error('UserService: Error updating goals', e, st);
      rethrow;
    }
  }

  Future<String> getBillingPortalUrl() async {
    _logger.info('UserService: Getting billing portal URL');
    try {
      final response = await _client.post('/api/billing/portal');

      if (response.statusCode == 200) {
        final data = response.data;
        return data['url'];
      }
      throw Exception('Failed to get portal URL');
    } catch (e, st) {
      _logger.error('UserService: Error getting portal URL', e, st);
      rethrow;
    }
  }

  Future<void> resetOnboarding() async {
    _logger.info('UserService: Resetting onboarding');
    try {
      final response = await _client.post('/api/user/reset-onboarding');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to reset onboarding');
      }
    } catch (e) {
      throw Exception('Failed to reset onboarding');
    }
  }

  Future<void> logActivity({
    required DateTime startTime,
    required int durationInSeconds,
    required String activityType,
    required String targetLanguage,
  }) async {
    try {
      await _client.post(
        '/api/user/activity-log',
        data: {
          'startTime': startTime.toIso8601String(),
          'durationInSeconds': durationInSeconds,
          'activityType': activityType,
          'targetLanguage': targetLanguage,
        },
      );
    } catch (e) {
      _logger.warning('Failed to log activity: $e');
    }
  }
}

final userServiceProvider = Provider(
  (ref) => UserService(ref.watch(apiClientProvider), ref),
);
