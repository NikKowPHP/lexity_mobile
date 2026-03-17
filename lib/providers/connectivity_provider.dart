import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  final ConnectivityService _service;

  ConnectivityNotifier(this._service) : super(true) {
    _init();
  }

  void _init() async {
    state = await _service.checkConnectivity();
    _service.startMonitoring();
    _service.connectivityStream.listen((isOnline) {
      state = isOnline;
    });
  }

  Future<void> refresh() async {
    state = await _service.checkConnectivity();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((
  ref,
) {
  final service = ref.watch(connectivityServiceProvider);
  return ConnectivityNotifier(service);
});
