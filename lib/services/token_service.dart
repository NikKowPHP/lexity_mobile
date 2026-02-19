import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

enum TokenType { auth, refresh }

class TokenService {
  final Ref ref;
  final TokenType tokenType;
  late final LoggerService _logger;
  
  static const Map<TokenType, String> _tokenKeys = {
    TokenType.auth: 'auth_token',
    TokenType.refresh: 'refresh_token',
  };

  TokenService(this.ref, this.tokenType) {
    _logger = ref.read(loggerProvider);
  }

  String get _tokenKey => _tokenKeys[tokenType]!;
  String get _serviceName => tokenType == TokenType.auth ? 'AuthService' : 'AuthRefreshService';

  Future<void> saveToken(String token) async {
    _logger.info('$_serviceName: Saving ${tokenType.name} token');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _logger.info('$_serviceName: Token saved successfully');
    } catch (e, stackTrace) {
      _logger.error('$_serviceName: Error saving token', e, stackTrace);
      rethrow;
    }
  }

  Future<String?> getToken() async {
    _logger.info('$_serviceName: Retrieving ${tokenType.name} token');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      _logger.info(
        '$_serviceName: Token retrieved: ${token != null ? "found" : "not found"}',
      );
      return token;
    } catch (e, stackTrace) {
      _logger.error('$_serviceName: Error retrieving token', e, stackTrace);
      rethrow;
    }
  }

  Future<void> clearToken() async {
    _logger.info('$_serviceName: Clearing ${tokenType.name} token');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      _logger.info('$_serviceName: Token cleared successfully');
    } catch (e, stackTrace) {
      _logger.error('$_serviceName: Error clearing token', e, stackTrace);
      rethrow;
    }
  }
}

// Providers
final tokenServiceProvider = Provider.family<TokenService, TokenType>(
  (ref, tokenType) => TokenService(ref, tokenType),
);

final authTokenServiceProvider = Provider<TokenService>((ref) => 
  TokenService(ref, TokenType.auth),
);

final refreshTokenServiceProvider = Provider<TokenService>((ref) => 
  TokenService(ref, TokenType.refresh),
);
