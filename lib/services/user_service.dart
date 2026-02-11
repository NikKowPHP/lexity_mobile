import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import '../models/user_profile.dart';
import 'logger_service.dart';

class UserService {
  final Ref _ref;
  final AuthService _auth;
  late final LoggerService _logger;

  UserService(this._ref, this._auth) {
    _logger = _ref.read(loggerProvider);
  }

  Future<UserProfile> fetchProfile() async {
    _logger.info('UserService: Fetching user profile');
    try {
      final token = await _auth.getToken();
      
      // DEBUG: Check if token looks like a real JWT (starts with ey...)
      print(
        "Sending Token: ${token?.substring(0, token.length > 10 ? 10 : token.length)}...",
      );

      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile'),
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
      final token = await _auth.getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(profile.toJson()),
      );

      _logger.debug('UserService: updateProfile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('UserService: Profile updated successfully');
        return UserProfile.fromJson(data);
      }

      final errorMsg = jsonDecode(response.body)['error'] ?? 'Failed to update profile';
      _logger.warning('UserService: Profile update failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('UserService: Error during updateProfile', e, stackTrace);
      rethrow;
    }
  }
}

final userServiceProvider = Provider((ref) => UserService(ref, ref.watch(authServiceProvider)));
