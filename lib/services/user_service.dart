import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../models/user_profile.dart';
import 'logger_service.dart';
import '../utils/constants.dart';

class UserService {
  final Ref _ref;
  final TokenService _authTokenService;
  late final LoggerService _logger;

  UserService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

  Future<UserProfile> fetchProfile() async {
    _logger.info('UserService: Fetching user profile');
    try {
      final token = await _authTokenService.getToken();
      
      // FIX: Use null-aware operators to prevent crash if token is null
      final tokenPreview = token != null 
        ? "${token.substring(0, token.length > 10 ? 10 : token.length)}..."
        : "null";

      print("Sending Token: $tokenPreview");

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      _logger.debug('UserService: fetchProfile response status: ${response.statusCode}');

      if (response.statusCode == 401) {
        _logger.warning(
          'UserService: Backend rejected token. Check Supabase JWT secrets match.',
        );
        throw Exception('Unauthorized');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('UserService: Profile fetched successfully');
        return UserProfile.fromJson(data);
      }

      final errorMsg = jsonDecode(response.body)['error'] ?? 'Failed to load profile';
      _logger.warning('UserService: Profile fetch failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('UserService: Error during fetchProfile', e, stackTrace);
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
        'targetLanguage': profile.defaultTargetLanguage, // API expects 'targetLanguage' to update default
        'writingStyle': profile.writingStyle,
        'writingPurpose': profile.writingPurpose,
        'selfAssessedLevel': profile.selfAssessedLevel,
      };

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );

      _logger.debug('UserService: updateProfile response status: ${response.statusCode}');

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
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'newTargetLanguage': newLanguage,
        }),
      );
      
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
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/user/reset-onboarding'),
        headers: {'Authorization': 'Bearer $token'},
      );
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
      await http.post(
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
    } catch (e) {
      _logger.warning('Failed to log activity: $e');
    }
  }
}

final userServiceProvider = Provider((ref) => UserService(ref, ref.watch(tokenServiceProvider(TokenType.auth))));
