import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/connectivity_provider.dart';
import '../services/logger_service.dart';
import '../services/sync_service.dart';
import '../network/api_client.dart';

class HydrationService {
  final AppDatabase _db;
  final Ref _ref;
  final ApiClient _client;
  final LoggerService _logger;
  DateTime? _lastSyncTimestamp;

  HydrationService(this._db, this._ref, this._client, this._logger);

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<void> performFullSync() async {
    if (!_isOnline) {
      _logger.info('HydrationService: Offline, skipping sync');
      return;
    }

    _logger.info('HydrationService: Delegating to Delta Sync Engine');
    try {
      await _ref.read(syncServiceProvider).performDeltaSync();
      
      _lastSyncTimestamp = DateTime.now();
      _ref.read(lastSyncTimeProvider.notifier).state = _lastSyncTimestamp;
    } catch (e, st) {
      _logger.error('HydrationService: Sync failed', e, st);
      rethrow;
    }
  }

  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;
}

final hydrationServiceProvider = Provider<HydrationService>((ref) {
  final db = ref.watch(databaseProvider);
  final logger = ref.watch(loggerProvider);
  final client = ref.watch(apiClientProvider);
  return HydrationService(db, ref, client, logger);
});

final hydrationTriggerProvider = FutureProvider<void>((ref) async {
  final hydrationService = ref.watch(hydrationServiceProvider);
  await hydrationService.performFullSync();
});
