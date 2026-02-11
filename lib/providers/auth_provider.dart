// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  AuthNotifier(this._authService, this._userService, this._logger)
    : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _logger.info('AuthNotifier: checking auth status (Deep Auth Check)');
    final token = await _authService.getToken();
    
    if (token == null) {
      _logger.info('AuthNotifier: no token found');
      state = state.copyWith(isAuthenticated: false, isInitialized: true);
      return;
    }

    try {
      // PERFORM THE "ME" CHECK: Try to fetch the profile from the server
      // This verifies the JWT is actually valid and not expired.
      await _userService.fetchProfile();

      _logger.info('AuthNotifier: token valid, authenticating');
      state = state.copyWith(isAuthenticated: true, isInitialized: true);
    } catch (e) {
      // If the server says 401 (Unauthorized), the token is likely expired or invalid
      _logger.warning("AuthNotifier: Deep Auth Check failed: $e");
      await _authService.clearToken(); // Wipe the invalid token
      state = state.copyWith(isAuthenticated: false, isInitialized: true);
    }
  }

  Future<void> logout() async {
    _logger.info('AuthNotifier: logging out');
    await _authService.clearToken();
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
  return AuthNotifier(authService, userService, logger);
});
