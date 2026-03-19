import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../services/auth_service.dart';

import '../services/user_service.dart';
import '../services/logger_service.dart';
import '../providers/connectivity_provider.dart';
import '../database/app_database.dart';

class AuthState {
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final String? accessToken;

  AuthState({
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.accessToken,
  });

  AuthState copyWith({
    bool? isInitialized,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    String? accessToken,
  }) {
    return AuthState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final LoggerService _logger;
  late final TokenService _authTokenService;
  late final TokenService _refreshTokenService;
  String? _cachedToken;

  Completer<List<String>?>? _refreshOngoing;

  @override
  AuthState build() {
    _logger = ref.read(loggerProvider);
    _authTokenService = ref.read(tokenServiceProvider(TokenType.auth));
    _refreshTokenService = ref.read(tokenServiceProvider(TokenType.refresh));
    checkAuthStatus();
    return AuthState();
  }

  Future<String?> getValidToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    final token = await _authTokenService.getToken();
    _cachedToken = token;
    return token;
  }

  String? get cachedToken => _cachedToken;

  String _mapErrorToString(dynamic e) {
    // Try to extract error message from response body first
    if (e is DioException && e.response?.data != null) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        final backendError = responseData['error'] as String?;
        if (backendError != null && backendError.isNotEmpty) {
          return _sanitizeBackendError(backendError);
        }
      }
    }

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return "Connection timed out. Please check your internet.";
        case DioExceptionType.connectionError:
          return "Unable to connect to the server. Are you online?";
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode;
          if (status == 401) return "Incorrect email or password.";
          if (status == 400) return "Invalid login details. Please try again.";
          if (status == 409) {
            return "An account with this email already exists.";
          }
          if (status == 429) {
            return "Too many attempts. Please try again later.";
          }
          if (status == 500) return "Server error. We're working on it!";
          return "Something went wrong (Error $status).";
        default:
          return "An unexpected network error occurred.";
      }
    }

    final msg = e.toString().replaceAll("Exception: ", "");
    if (msg.contains("Invalid login credentials")) {
      return "Incorrect email or password.";
    }

    return "Something went wrong. Please try again.";
  }

  /// Sanitizes backend error messages to user-friendly ones
  String _sanitizeBackendError(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains("email and password are required") ||
        lowerError.contains("email is required") ||
        lowerError.contains("password is required")) {
      return "Please enter both email and password.";
    }
    if (lowerError.contains("password should be at least")) {
      return "Password is too short. Use at least 6 characters.";
    }
    if (lowerError.contains("user already registered")) {
      return "An account with this email already exists.";
    }
    if (lowerError.contains("invalid email") ||
        lowerError.contains("email must be valid")) {
      return "Please enter a valid email address.";
    }
    if (lowerError.contains("rate limit")) {
      return "Too many attempts. Please try again later.";
    }
    if (lowerError.contains("too many requests")) {
      return "Too many attempts. Please try again later.";
    }

    // Return the backend error as-is if no specific mapping
    return error;
  }

  Future<String?> forceRefreshToken() async {
    final refreshedTokens = await refreshToken();
    if (refreshedTokens != null && refreshedTokens.length >= 2) {
      await _authTokenService.saveToken(refreshedTokens[0]);
      await _refreshTokenService.saveToken(refreshedTokens[1]);
      _cachedToken = refreshedTokens[0];
      _logger.info('AuthNotifier: Token force refreshed successfully');
      return refreshedTokens[0];
    }
    return null;
  }

  Future<void> checkAuthStatus() async {
    _logger.info('AuthNotifier: checking auth status');
    final token = await _authTokenService.getToken();

    if (token == null) {
      _logger.info('AuthNotifier: no token found on disk');
      state = state.copyWith(isAuthenticated: false, isInitialized: true);
      return;
    }

    _cachedToken = token;

    _logger.info('AuthNotifier: Token found. Optimistically authenticating.');
    state = state.copyWith(
      isAuthenticated: true,
      isInitialized: false,
      accessToken: token,
    );

    try {
      final isOnline = ref.read(connectivityProvider);

      if (isOnline) {
        final userService = ref.read(userServiceProvider);
        await userService.fetchProfile();
        _logger.info('AuthNotifier: Profile synced successfully');
      } else {
        _logger.info('AuthNotifier: Offline, relying on local session');
      }

      state = state.copyWith(isInitialized: true);
    } catch (e) {
      _logger.warning("AuthNotifier: Background sync failed: $e");

      if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        _logger.info("AuthNotifier: Token expired, trying to refresh...");

        final refreshedTokens = await refreshToken();
        if (refreshedTokens != null && refreshedTokens.length >= 2) {
          await _authTokenService.saveToken(refreshedTokens[0]);
          await _refreshTokenService.saveToken(refreshedTokens[1]);
          _cachedToken = refreshedTokens[0];
          _logger.info(
            "AuthNotifier: Token refreshed, retrying profile fetch...",
          );

          try {
            final userService = ref.read(userServiceProvider);
            await userService.fetchProfile();
            _logger.info("AuthNotifier: Profile fetched after token refresh");
            state = state.copyWith(
              isInitialized: true,
              accessToken: refreshedTokens[0],
            );
          } catch (retryError) {
            _logger.warning(
              "AuthNotifier: Profile fetch failed after refresh: $retryError",
            );
            await logout();
          }
        } else {
          _logger.warning("AuthNotifier: Token refresh failed, logging out.");
          await logout();
        }
      } else {
        state = state.copyWith(isInitialized: true);
      }
    }
  }

  Future<List<String>?> refreshToken() async {
    if (_refreshOngoing != null) {
      _logger.info(
        'AuthNotifier: Refresh already in progress, waiting for it...',
      );
      return await _refreshOngoing!.future;
    }

    _refreshOngoing = Completer<List<String>?>();
    try {
      final result = await _performRefresh();
      _refreshOngoing!.complete(result);
      return result;
    } catch (e) {
      _refreshOngoing!.completeError(e);
      rethrow;
    } finally {
      _refreshOngoing = null;
    }
  }

  Future<List<String>?> _performRefresh() async {
    _logger.info(
      'AuthNotifier: performing token refresh, retrieving from storage',
    );
    final token = await _refreshTokenService.getToken();
    if (token == null) {
      _logger.info('AuthNotifier: no refresh token found in storage');
      return null;
    }

    try {
      final authService = ref.read(authServiceProvider);
      final refreshedAuthToken = await authService.refreshToken(token);
      _logger.info('AuthNotifier: refresh token request successful');
      return refreshedAuthToken;
    } catch (e) {
      _logger.error('AuthNotifier: refresh token request failed', e);
      return null;
    }
  }

  Future<void> logout() async {
    _logger.info('AuthNotifier: logging out');
    // Clear both tokens to prevent the "invalid token" loop
    await _authTokenService.clearToken();
    await _refreshTokenService.clearToken();
    _cachedToken = null;

    // Clear all user data from local database
    final db = ref.read(databaseProvider);
    await db.clearAllUserData();
    _logger.info('AuthNotifier: cleared user data on logout');

    state = state.copyWith(
      isAuthenticated: false,
      isInitialized: true,
      accessToken: null,
    );
  }

  Future<void> login(String email, String password) async {
    _logger.info('AuthNotifier: login started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Clear all user data before logging in as a different user
      final db = ref.read(databaseProvider);
      await db.clearAllUserData();
      _logger.info('AuthNotifier: cleared previous user data');

      final authService = ref.read(authServiceProvider);
      await authService.login(email, password);
      _logger.info('AuthNotifier: login successful for $email');
      final token = await _authTokenService.getToken();
      _cachedToken = token;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isInitialized: true,
        accessToken: token,
      );
    } catch (e, stackTrace) {
      _logger.error('AuthNotifier: login failed for $email', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: _mapErrorToString(e),
        isInitialized: true,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    _logger.info('AuthNotifier: signup started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Clear all user data before signing up
      final db = ref.read(databaseProvider);
      await db.clearAllUserData();
      _logger.info('AuthNotifier: cleared previous user data');

      final authService = ref.read(authServiceProvider);
      await authService.signUp(email, password);
      _logger.info('AuthNotifier: signup successful for $email');
      final token = await _authTokenService.getToken();
      _cachedToken = token;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isInitialized: true,
        accessToken: token,
      );
    } catch (e, stackTrace) {
      _logger.error('AuthNotifier: signup failed for $email', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: _mapErrorToString(e),
        isInitialized: true,
      );
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
