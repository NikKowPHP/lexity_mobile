import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  final Connectivity _connectivity;
  StreamController<bool>? _connectivityController;

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    return _connectivityController!.stream;
  }

  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  void startMonitoring() {
    _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = _isOnline(results);
      _connectivityController?.add(isOnline);
    });
  }

  void stopMonitoring() {
    _connectivityController?.close();
    _connectivityController = null;
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet,
    );
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.stopMonitoring());
  return service;
});
