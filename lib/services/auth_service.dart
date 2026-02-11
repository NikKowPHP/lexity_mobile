// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

// Change this based on your device
final String baseUrl = Platform.isAndroid
    ? 'http://10.0.2.2:3555'
    : 'http://localhost:3555';

class AuthService {
  final Ref ref;
  late final LoggerService _logger;

  AuthService(this.ref) {
    _logger = ref.read(loggerProvider);
  }

  Future<void> saveToken(String token) async {
    _logger.info('Saving auth token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    _logger.info('Retrieving auth token');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> clearToken() async {
    _logger.info('Clearing auth token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<bool> login(String email, String password) async {
    _logger.info('Attempting login for user: $email');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      _logger.debug('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Assuming your API returns session.access_token or similar
        // Adjust parsing based on exact API response structure in route.ts
        if (data['session'] != null &&
            data['session']['access_token'] != null) {
          await saveToken(data['session']['access_token']);
          _logger.info('Login successful for user: $email');
          return true;
        }
      }
      final errorMsg = jsonDecode(response.body)['error'] ?? 'Login failed';
      _logger.warning('Login failed for user: $email. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('Login error for user: $email', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _logger.info('Attempting signup for user: $email');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      _logger.debug('Signup response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['session'] != null &&
            data['session']['access_token'] != null) {
          await saveToken(data['session']['access_token']);
          _logger.info('Signup successful for user: $email');
          return true;
        }
      }
      final errorMsg = jsonDecode(response.body)['error'] ?? 'Signup failed';
      _logger.warning('Signup failed for user: $email. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('Signup error for user: $email', e, stackTrace);
      rethrow;
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService(ref));
