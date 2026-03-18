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

  Future<List<String>?>? _refreshOngoing;

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
      return await _refreshOngoing;
    }

    _refreshOngoing = _performRefresh();
    final result = await _refreshOngoing;
    _refreshOngoing = null;
    return result;
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
    await _authTokenService.clearToken();
    _cachedToken = null;
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
        error: e.toString().replaceAll("Exception: ", ""),
        isInitialized: true,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    _logger.info('AuthNotifier: signup started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
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
        error: e.toString().replaceAll("Exception: ", ""),
        isInitialized: true,
      );
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
