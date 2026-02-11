// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

import '../services/logger_service.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({this.isLoading = false, this.error, this.isAuthenticated = false});

  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable override
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  late final LoggerService _logger;

  AuthNotifier(this._authService, this._logger) : super(AuthState());

  Future<void> login(String email, String password) async {
    _logger.info('AuthNotifier: login started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.login(email, password);
      _logger.info('AuthNotifier: login successful for $email');
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } catch (e, stackTrace) {
      _logger.error('AuthNotifier: login failed for $email', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll("Exception: ", ""),
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    _logger.info('AuthNotifier: signup started for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signUp(email, password);
      _logger.info('AuthNotifier: signup successful for $email');
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } catch (e, stackTrace) {
      _logger.error('AuthNotifier: signup failed for $email', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll("Exception: ", ""),
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final logger = ref.watch(loggerProvider);
  return AuthNotifier(authService, logger);
});
