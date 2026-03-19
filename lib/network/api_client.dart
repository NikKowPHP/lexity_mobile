import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));

class ApiClient {
  late final Dio _dio;
  final Ref _ref;
  late final LoggerService _logger;

  ApiClient(this._ref) {
    _logger = _ref.read(loggerProvider);
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.addAll([
      AuthInterceptor(_ref, _logger),
      TokenRefreshInterceptor(_ref, _logger),
      _LoggingInterceptor(_logger),
    ]);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> download(
    String path,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _dio.download(
      path,
      savePath,
      options: Options(headers: headers),
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
    );
  }

  Dio get dio => _dio;
}

class AuthInterceptor extends Interceptor {
  final Ref _ref;
  final LoggerService _logger;

  AuthInterceptor(this._ref, this._logger);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final authNotifier = _ref.read(authProvider.notifier);
      String? token = authNotifier.cachedToken;
      token ??= await authNotifier.getValidToken();

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      handler.next(options);
    } catch (e, st) {
      _logger.error('AuthInterceptor: Error getting token', e, st);
      handler.next(options);
    }
  }
}

class TokenRefreshInterceptor extends Interceptor {
  final Ref _ref;
  final LoggerService _logger;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  TokenRefreshInterceptor(this._ref, this._logger);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't intercept 401s for the refresh token endpoint itself to avoid loops
    final isRefreshPath = err.requestOptions.path.contains('/api/auth/refresh');

    if (err.response?.statusCode == 401 && !isRefreshPath) {
      _logger.info('TokenRefreshInterceptor: 401 detected, attempting refresh');

      if (_isRefreshing) {
        _logger.info(
          'TokenRefreshInterceptor: Refresh in progress, queuing request',
        );
        final completer = Completer<Response<dynamic>>();
        _pendingRequests.add(_PendingRequest(err.requestOptions, completer));
        try {
          final response = await completer.future;
          return handler.resolve(response);
        } catch (e) {
          // Refresh failed for a queued request - the logout has already been triggered
          // Pass a specific error that callers can check for
          final authError = DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: DioExceptionType.badResponse,
            message: 'AUTH_EXPIRED',
          );
          return handler.next(authError);
        }
      }

      _isRefreshing = true;

      try {
        final newToken = await _ref
            .read(authProvider.notifier)
            .forceRefreshToken();

        if (newToken != null) {
          _logger.info(
            'TokenRefreshInterceptor: Token refreshed, retrying request',
          );

          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';

          final retryResponse = await Dio().fetch(opts);
          _processQueue(retryResponse);
          return handler.resolve(retryResponse);
        } else {
          _logger.warning(
            'TokenRefreshInterceptor: Token refresh failed, logging out user',
          );
          await _ref.read(authProvider.notifier).logout();
          _processQueue(null);
          return handler.next(err);
        }
      } catch (e) {
        _logger.error('TokenRefreshInterceptor: Refresh error', e);
        _logger.warning(
          'TokenRefreshInterceptor: Refresh exception, logging out user',
        );
        await _ref.read(authProvider.notifier).logout();
        _processQueue(null);
        return handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(err);
  }

  void _processQueue(Response<dynamic>? response) {
    for (final pending in _pendingRequests) {
      if (response != null) {
        pending.completer.complete(response);
      } else {
        pending.completer.completeError(Exception('Token refresh failed'));
      }
    }
    _pendingRequests.clear();
  }
}

class _PendingRequest {
  final RequestOptions options;
  final Completer<Response<dynamic>> completer;

  _PendingRequest(this.options, this.completer);
}

class _LoggingInterceptor extends Interceptor {
  final LoggerService _logger;

  _LoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('API Request: ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.debug(
      'API Response: ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.error(
      'API Error: ${err.response?.statusCode} ${err.requestOptions.uri}',
      err,
    );
    handler.next(err);
  }
}
