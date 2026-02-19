// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../services/auth_service.dart';

import '../services/user_service.dart';
import '../services/logger_service.dart';

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
  late final LoggerService _logger;
  late final TokenService _authTokenService;
  late final TokenService _refreshTokenService;

  AuthNotifier(
    this._authService,
    this._userService,
    this._logger,
    this._authTokenService,
    this._refreshTokenService,
  ) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _logger.info('AuthNotifier: checking auth status (Deep Auth Check)');
    final token = await _authTokenService.getToken();

    if (token == null) {
      _logger.info('AuthNotifier: no token found');
      state = state.copyWith(isAuthenticated: false, isInitialized: true);
      return;
    }

    try {
      await _userService.fetchProfile();

      _logger.info('AuthNotifier: token valid, authenticating');
      state = state.copyWith(isAuthenticated: true, isInitialized: true);
    } catch (e) {
      _logger.warning("AuthNotifier: Deep Auth Check failed: $e");
      final refreshedAuthTokens = await refreshToken();
      if (refreshedAuthTokens != null && refreshedAuthTokens.length >= 2) {
        await _authTokenService.saveToken(refreshedAuthTokens[0]);
        await _refreshTokenService.saveToken(refreshedAuthTokens[1]);
        state = state.copyWith(isAuthenticated: true, isInitialized: true);
      } else {
        _logger.warning(
          "AuthNotifier: Token refresh failed or returned invalid data, clearing tokens",
        );
        await _authTokenService.clearToken();
        await _refreshTokenService.clearToken();
        state = state.copyWith(isAuthenticated: false, isInitialized: true);
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
    authService,
    userService,
    logger,
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(tokenServiceProvider(TokenType.refresh)),
  );
});
