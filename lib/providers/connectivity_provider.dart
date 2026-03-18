import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

class ConnectivityNotifier extends Notifier<bool> {
  late final ConnectivityService _service;

  @override
  bool build() {
    _service = ref.watch(connectivityServiceProvider);
    _init();
    return true;
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

final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(() {
  return ConnectivityNotifier();
});
