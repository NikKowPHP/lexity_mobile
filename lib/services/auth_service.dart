// lib/services/auth_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lexity_mobile/services/token_service.dart';

import 'logger_service.dart';
import 'hydration_service.dart';
import '../network/api_client.dart';

class AuthService {
  final Ref ref;
  final ApiClient _client;
  late final LoggerService _logger;
  late final TokenService _authTokenService;
  late final TokenService _refreshTokenService;

  AuthService(this.ref, this._client) {
    _logger = ref.read(loggerProvider);
    _authTokenService = ref.read(tokenServiceProvider(TokenType.auth));
    _refreshTokenService = ref.read(tokenServiceProvider(TokenType.refresh));
  }

  Future<bool> login(String email, String password) async {
    _logger.info('AuthService: Attempting login for user: $email');
    try {
      final response = await _client.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      _logger.debug(
        'AuthService: Login response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _logger.debug('AuthService: Login response body: $data');

        if (data['access_token'] != null) {
          await _authTokenService.saveToken(data['access_token']);
          _logger.info(
            'AuthService: Login successful (flat structure) for user: $email',
          );

          _logger.info('DATA FROM LOGIN RESPONSE: $data');

          await _syncUser(data['access_token']);

          await ref.read(hydrationServiceProvider).performFullSync();
        }
        if (data['refresh_token'] != null) {
          await _refreshTokenService.saveToken(data['refresh_token']);
          _logger.info(
            'AuthService: Login successful (nested structure) for user: $email',
          );
        }
        return true;
      }

      final responseData = response.data as Map<String, dynamic>;
      final errorMsg = responseData['error'] ?? 'Login failed';
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
      final response = await _client.post(
        '/api/auth/register',
        data: {'email': email, 'password': password},
      );

      _logger.debug(
        'AuthService: Signup response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _logger.info('DATA FROM SIGNUP RESPONSE: $data');

        // Backend returns {access_token, refresh_token, user} — no session wrapper
        final accessToken =
            data['access_token'] ?? (data['session']?['access_token']);
        if (accessToken != null) {
          await _authTokenService.saveToken(accessToken);
          _logger.info('AuthService: Signup successful for user: $email');

          // Also save refresh token if present
          if (data['refresh_token'] != null) {
            await _refreshTokenService.saveToken(data['refresh_token']);
          }

          // Sync user to local DB after registration
          await _syncUser(accessToken);
          await ref.read(hydrationServiceProvider).performFullSync();

          return true;
        }
      }
      final responseData = response.data as Map<String, dynamic>;
      final errorMsg = responseData['error'] ?? 'Signup failed';
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
      final response = await _client.post(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      List<String> authResponse = [];

      _logger.debug(
        'AuthService: Refresh token response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
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
      final responseData = response.data as Map<String, dynamic>;
      final errorMsg = responseData['error'] ?? 'Refresh token failed';
      _logger.warning('AuthService: Refresh token failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('AuthService: Refresh token error', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _syncUser(String token) async {
    try {
      await _client.post('/api/auth/sync-user');
    } catch (e) {
      _logger.warning('AuthService: User sync failed (non-critical)', e);
    }
  }
}

final authServiceProvider = Provider(
  (ref) => AuthService(ref, ref.watch(apiClientProvider)),
);
