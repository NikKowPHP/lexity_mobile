// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../services/auth_service.dart';

import '../services/user_service.dart';
import '../services/logger_service.dart';
import '../providers/connectivity_provider.dart';

class AuthState {
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isInitialized,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable override
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final UserService _userService;
  final Ref _ref;
  late final LoggerService _logger;
  late final TokenService _authTokenService;
  late final TokenService _refreshTokenService;

  AuthNotifier(
    this._ref,
    this._authService,
    this._userService,
    this._logger,
    this._authTokenService,
    this._refreshTokenService,
  ) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _logger.info('AuthNotifier: checking auth status');
    final token = await _authTokenService.getToken();

    if (token == null) {
      _logger.info('AuthNotifier: no token found on disk');
      state = state.copyWith(isAuthenticated: false, isInitialized: true);
      return;
    }

    // Token exists - optimistically authenticate
    _logger.info('AuthNotifier: Token found. Optimistically authenticating.');
    state = state.copyWith(isAuthenticated: true, isInitialized: false);

    try {
      final isOnline = _ref.read(connectivityProvider);

      if (isOnline) {
        await _userService.fetchProfile();
        _logger.info('AuthNotifier: Profile synced successfully');
      } else {
        _logger.info('AuthNotifier: Offline, relying on local session');
      }

      state = state.copyWith(isInitialized: true);
    } catch (e) {
      _logger.warning("AuthNotifier: Background sync failed: $e");

      // Only logout if it's a 401 Unauthorized - try to refresh token first
      if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        _logger.info("AuthNotifier: Token expired, trying to refresh...");

        final refreshedTokens = await refreshToken();
        if (refreshedTokens != null && refreshedTokens.length >= 2) {
          await _authTokenService.saveToken(refreshedTokens[0]);
          await _refreshTokenService.saveToken(refreshedTokens[1]);
          _logger.info(
            "AuthNotifier: Token refreshed, retrying profile fetch...",
          );

          try {
            await _userService.fetchProfile();
            _logger.info("AuthNotifier: Profile fetched after token refresh");
            state = state.copyWith(isInitialized: true);
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
        // Network error - keep user logged in but mark initialized
        state = state.copyWith(isInitialized: true);
      }
    }
  }

  Future<List<String>?> refreshToken() async {
    _logger.info('AuthNotifier: refreshing token, retrieving from storage');
    final token = await _refreshTokenService.getToken();
    if (token == null) {
      _logger.info('AuthNotifier: no refresh token found in storage');
      return null;
    }

    try {
      final refreshedAuthToken = await _authService.refreshToken(token);
      return refreshedAuthToken;
    } catch (e) {
      _logger.error('AuthNotifier: refresh token request failed', e);
      return null;
    }
  }

  Future<void> logout() async {
    _logger.info('AuthNotifier: logging out');
    await _authTokenService.clearToken();
    state = state.copyWith(isAuthenticated: false, isInitialized: true);
  }

  Future<void> login(String email, String password) async {
    _logger.info('AuthNotifier: login started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.login(email, password);
      _logger.info('AuthNotifier: login successful for $email');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isInitialized: true,
      );
    } catch (e, stackTrace) {
      _logger.error('AuthNotifier: login failed for $email', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll("Exception: ", ""),
        isInitialized: true,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    _logger.info('AuthNotifier: signup started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signUp(email, password);
      _logger.info('AuthNotifier: signup successful for $email');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isInitialized: true,
      );
    } catch (e, stackTrace) {
      _logger.error('AuthNotifier: signup failed for $email', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll("Exception: ", ""),
        isInitialized: true,
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userService = ref.watch(userServiceProvider);
  final logger = ref.watch(loggerProvider);
  return AuthNotifier(
    ref,
    authService,
    userService,
    logger,
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(tokenServiceProvider(TokenType.refresh)),
  );
});
