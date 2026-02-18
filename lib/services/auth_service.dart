// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

// Change this based on your device
final String baseUrl = Platform.isAndroid
    ? 'http://localhost:3555'
    : 'http://localhost:3555';

class AuthService {
  final Ref ref;
  late final LoggerService _logger;

  AuthService(this.ref) {
    _logger = ref.read(loggerProvider);
  }

  Future<void> saveToken(String token) async {
    _logger.info('AuthService: Saving auth token');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      _logger.info('AuthService: Token saved successfully');
    } catch (e, stackTrace) {
      _logger.error('AuthService: Error saving token', e, stackTrace);
      rethrow;
    }
  }

  Future<String?> getToken() async {
    _logger.info('AuthService: Retrieving auth token');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      _logger.info(
        'AuthService: Token retrieved: ${token != null ? "found" : "not found"}',
      );
      return token;
    } catch (e, stackTrace) {
      _logger.error('AuthService: Error retrieving token', e, stackTrace);
      rethrow;
    }
  }

  Future<void> clearToken() async {
    _logger.info('AuthService: Clearing auth token');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      _logger.info('AuthService: Token cleared successfully');
    } catch (e, stackTrace) {
      _logger.error('AuthService: Error clearing token', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> login(String email, String password) async {
    _logger.info('AuthService: Attempting login for user: $email');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      _logger.debug(
        'AuthService: Login response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.debug('AuthService: Login response body: $data');

        // Handle both flat structure (custom API) and nested structure (standard Supabase)
        if (data['access_token'] != null) {
          await saveToken(data['access_token']);
          _logger.info(
            'AuthService: Login successful (flat structure) for user: $email',
          );
          return true;
        } else if (data['session'] != null &&
            data['session']['access_token'] != null) {
          await saveToken(data['session']['access_token']);
          _logger.info(
            'AuthService: Login successful (nested structure) for user: $email',
          );
          return true;
        }
      }
      
      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? 'Login failed';
      _logger.warning(
        'AuthService: Login failed for user: $email. Reason: $errorMsg',
      );
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('AuthService: Login error for user: $email', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _logger.info('AuthService: Attempting signup for user: $email');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      _logger.debug(
        'AuthService: Signup response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['session'] != null &&
            data['session']['access_token'] != null) {
          await saveToken(data['session']['access_token']);
          _logger.info('AuthService: Signup successful for user: $email');
          return true;
        }
      }
      final errorMsg = jsonDecode(response.body)['error'] ?? 'Signup failed';
      _logger.warning(
        'AuthService: Signup failed for user: $email. Reason: $errorMsg',
      );
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error(
        'AuthService: Signup error for user: $email',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService(ref));
