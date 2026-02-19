// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:lexity_mobile/services/token_service.dart';

import 'logger_service.dart';

// Change this based on your device
final String baseUrl = Platform.isAndroid
    ? 'http://localhost:3555'
    : 'http://localhost:3555';

class AuthService {
  final Ref ref;
  late final LoggerService _logger;
  late final TokenService _authTokenService;
  late final TokenService _refreshTokenService;

  AuthService(this.ref) {
    _logger = ref.read(loggerProvider);
    _authTokenService = ref.read(tokenServiceProvider(TokenType.auth));
    _refreshTokenService = ref.read(tokenServiceProvider(TokenType.refresh));
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

        if (data['access_token'] != null) {
          await _authTokenService.saveToken(data['access_token']);
          _logger.info(
            'AuthService: Login successful (flat structure) for user: $email',
          );

          _logger.info('DATA FROM LOGIN RESPONSE: $data');
        }
        if (data['refresh_token'] != null) {
          await _refreshTokenService.saveToken(data['refresh_token']);
          _logger.info(
            'AuthService: Login successful (nested structure) for user: $email',
          );
        }
        return true;
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
          _logger.info('DATA FROM SIGNUP RESPONSE: $data');
          await _authTokenService.saveToken(data['session']['access_token']);
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

  Future<List<String>> refreshToken(String refreshToken) async {
    _logger.info('AuthService: Attempting to refresh token');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      List<String> authResponse = [];

      _logger.debug(
        'AuthService: Refresh token response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access_token'] != null) {
          await _authTokenService.saveToken(data['access_token']);
          _logger.info('AuthService: Token refreshed successfully');
          authResponse.add(data['access_token']);
        }
        if (data['refresh_token'] != null) {
          await _refreshTokenService.saveToken(data['refresh_token']);
          _logger.info('AuthService: Refresh token refreshed successfully');
          authResponse.add(data['refresh_token']);
        }
        return authResponse;
      }
      final errorMsg =
          jsonDecode(response.body)['error'] ?? 'Refresh token failed';
      _logger.warning('AuthService: Refresh token failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('AuthService: Refresh token error', e, stackTrace);
      rethrow;
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService(ref));
