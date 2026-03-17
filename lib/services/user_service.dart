import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../models/user_profile.dart';
import 'logger_service.dart';
import '../utils/constants.dart';
import '../providers/connectivity_provider.dart';
import '../providers/auth_provider.dart';
import '../database/app_database.dart';

class UserService {
  final Ref _ref;
  final TokenService _authTokenService;
  late final LoggerService _logger;

  UserService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

  /// Handles 401 errors by attempting to refresh the token and retrying the request.
  Future<bool> _handleUnauthorizedAndRetry(
    Future<http.Response> Function() requestFn,
  ) async {
    _logger.warning('UserService: 401 detected, attempting token refresh');

    final newToken = await _ref.read(authProvider.notifier).forceRefreshToken();

    if (newToken != null) {
      _logger.info('UserService: Token refreshed, retrying request');
      final retryResponse = await requestFn();
      return retryResponse.statusCode == 200;
    }

    _logger.warning('UserService: Token refresh failed');
    return false;
  }

  Future<UserProfile> fetchProfile() async {
    _logger.info('UserService: Fetching user profile');

    final isOnline = _ref.read(connectivityProvider);
    final db = _ref.read(databaseProvider);

    // If offline, try to get from cache first
    if (!isOnline) {
      _logger.info('UserService: Offline, trying cache');
      final localUsers = await db.getAllUsers();
      if (localUsers.isNotEmpty) {
        _logger.info('UserService: Returning cached profile from DB');
        return UserProfile.fromJson(localUsers.first);
      }
      throw Exception('No cached profile available offline');
    }

    // Online - try API
    try {
      final token = await _authTokenService.getToken();

      final tokenPreview = token != null
          ? "${token.substring(0, token.length > 10 ? 10 : token.length)}..."
          : "null";

      _logger.debug("Sending Token: $tokenPreview");

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      _logger.debug(
        'UserService: fetchProfile response status: ${response.statusCode}',
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.get(
            Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
            headers: {
              'Authorization': 'Bearer $newToken',
              'Content-Type': 'application/json',
            },
          );
        });

        if (success) {
          // Re-fetch the profile with the new token
          final retryResponse = await http.get(
            Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
            headers: {
              'Authorization': 'Bearer ${await _authTokenService.getToken()}',
              'Content-Type': 'application/json',
            },
          );

          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            await db.insertUser(data);
            _logger.info(
              'UserService: Profile fetched and cached after token refresh',
            );
            return UserProfile.fromJson(data);
          }
        }

        _logger.warning(
          'UserService: Token refresh failed, falling back to cache',
        );
        final localUsers = await db.getAllUsers();
        if (localUsers.isNotEmpty) {
          return UserProfile.fromJson(localUsers.first);
        }
        throw Exception('Unauthorized - please log in again');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Cache the profile for offline use
        await db.insertUser(data);
        _logger.info('UserService: Profile fetched and cached successfully');
        return UserProfile.fromJson(data);
      }

      final errorMsg =
          jsonDecode(response.body)['error'] ?? 'Failed to load profile';
      _logger.warning('UserService: Profile fetch failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      // On error, try to fall back to cache
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
      final token = await _authTokenService.getToken();
      // We map the model fields to the API expectations
      final body = {
        'nativeLanguage': profile.nativeLanguage,
        'targetLanguage': profile
            .defaultTargetLanguage, // API expects 'targetLanguage' to update default
        'writingStyle': profile.writingStyle,
        'writingPurpose': profile.writingPurpose,
        'selfAssessedLevel': profile.selfAssessedLevel,
      };

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      _logger.debug(
        'UserService: updateProfile response status: ${response.statusCode}',
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.put(
            Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
            body: jsonEncode(body),
          );
        });

        if (success) {
          final retryResponse = await http.put(
            Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${await _authTokenService.getToken()}',
            },
            body: jsonEncode(body),
          );

          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            return UserProfile.fromJson(data);
          }
        }
        throw Exception('Unauthorized - please log in again');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data);
      }

      throw Exception('Failed to update profile');
    } catch (e, stackTrace) {
      _logger.error('UserService: Error during updateProfile', e, stackTrace);
      rethrow;
    }
  }

  // New specific call for adding a language
  Future<UserProfile> addLanguage(String newLanguage) async {
    _logger.info('UserService: Adding new language: $newLanguage');
    try {
      final token = await _authTokenService.getToken();
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'newTargetLanguage': newLanguage}),
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.put(
            Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
            body: jsonEncode({'newTargetLanguage': newLanguage}),
          );
        });

        if (success) {
          final retryResponse = await http.put(
            Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${await _authTokenService.getToken()}',
            },
            body: jsonEncode({'newTargetLanguage': newLanguage}),
          );

          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            return UserProfile.fromJson(data);
          }
        }
        throw Exception('Unauthorized - please log in again');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      final token = await _authTokenService.getToken();
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/user/goals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(goals.toJson()),
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.put(
            Uri.parse('${AppConstants.baseUrl}/api/user/goals'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
            body: jsonEncode(goals.toJson()),
          );
        });

        if (!success) {
          throw Exception('Unauthorized - please log in again');
        }
        return;
      }

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
      final token = await _authTokenService.getToken();
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/billing/portal'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.post(
            Uri.parse('${AppConstants.baseUrl}/api/billing/portal'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        });

        if (success) {
          final retryResponse = await http.post(
            Uri.parse('${AppConstants.baseUrl}/api/billing/portal'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${await _authTokenService.getToken()}',
            },
          );

          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            return data['url'];
          }
        }
        throw Exception('Unauthorized - please log in again');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      final token = await _authTokenService.getToken();
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/user/reset-onboarding'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.post(
            Uri.parse('${AppConstants.baseUrl}/api/user/reset-onboarding'),
            headers: {'Authorization': 'Bearer $newToken'},
          );
        });

        if (!success) {
          throw Exception('Unauthorized - please log in again');
        }
        return;
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
      final token = await _authTokenService.getToken();
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/user/activity-log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'startTime': startTime.toIso8601String(),
          'durationInSeconds': durationInSeconds,
          'activityType': activityType,
          'targetLanguage': targetLanguage,
        }),
      );

      // Handle 401 - try to refresh token and retry once
      if (response.statusCode == 401) {
        final success = await _handleUnauthorizedAndRetry(() async {
          final newToken = await _authTokenService.getToken();
          return await http.post(
            Uri.parse('${AppConstants.baseUrl}/api/user/activity-log'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
            body: jsonEncode({
              'startTime': startTime.toIso8601String(),
              'durationInSeconds': durationInSeconds,
              'activityType': activityType,
              'targetLanguage': targetLanguage,
            }),
          );
        });

        if (!success) {
          _logger.warning(
            'UserService: Activity logging failed after token refresh',
          );
          return;
        }
      }
    } catch (e) {
      _logger.warning('Failed to log activity: $e');
    }
  }
}

final userServiceProvider = Provider(
  (ref) => UserService(ref, ref.watch(tokenServiceProvider(TokenType.auth))),
);
