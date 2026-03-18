import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/srs_item.dart';
import '../../database/repositories/sync_repository.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/logger_service.dart';
import '../datasources/remote/srs_remote_datasource.dart';
import '../datasources/local/srs_local_datasource.dart';

class SrsRepository {
  final Ref _ref;
  final SrsRemoteDataSource _remoteDataSource;
  final SrsLocalDataSource _localDataSource;
  final SyncRepository _syncRepo;
  late final LoggerService _logger;

  SrsRepository(
    this._ref,
    this._remoteDataSource,
    this._localDataSource,
    this._syncRepo,
  ) {
    _logger = _ref.read(loggerProvider);
  }

  Future<List<SrsItem>> fetchDeck(String language) async {
    _syncDeckInBackground(language);
    return _localDataSource.getDueItems();
  }

  void _syncDeckInBackground(String language) {
    if (!_ref.read(connectivityProvider)) return;
    Future(() async {
      try {
        final items = await _remoteDataSource.fetchDeck(language);
        for (final item in items) {
          await _localDataSource.upsertFromRemote(item.toJson());
        }
        _logger.info(
          'SrsRepository: Background deck sync complete, ${items.length} items upserted',
        );
      } catch (e, st) {
        _logger.warning('SrsRepository: Background deck sync failed', e, st);
      }
    });
  }

  Future<List<SrsItem>> fetchAllItems(String language) async {
    _syncAllItemsInBackground(language);
    return _localDataSource.getAllItems();
  }

  void _syncAllItemsInBackground(String language) {
    if (!_ref.read(connectivityProvider)) return;
    Future(() async {
      try {
        final items = await _remoteDataSource.fetchAllItems(language);
        for (final item in items) {
          await _localDataSource.upsertFromRemote(item.toJson());
        }
        _logger.info(
          'SrsRepository: Background all-items sync complete, ${items.length} items upserted',
        );
      } catch (e, st) {
        _logger.warning(
          'SrsRepository: Background all-items sync failed',
          e,
          st,
        );
      }
    });
  }

  Future<void> reviewItem(String id, int quality) async {
    _logger.info(
      'SrsRepository: Processing review for item: $id, quality: $quality locally',
    );

    final nextReviewDate = _calculateNextReview(quality);

    await _localDataSource.updateReviewDate(id, nextReviewDate);

    await _syncRepo.enqueueSrsReview(id, nextReviewDate);

    _logger.info('SrsRepository: Review queued for sync for item: $id');
  }

  DateTime _calculateNextReview(int quality) {
    final now = DateTime.now();
    switch (quality) {
      case 0:
        return now.add(const Duration(minutes: 1));
      case 1:
        return now.add(const Duration(minutes: 10));
      case 2:
        return now.add(const Duration(days: 1));
      case 3:
        return now.add(const Duration(days: 3));
      case 4:
        return now.add(const Duration(days: 7));
      case 5:
        return now.add(const Duration(days: 14));
      default:
        return now.add(const Duration(days: 1));
    }
  }

  Future<SrsItem> createFromTranslation({
    required String front,
    required String back,
    required String language,
    String? explanation,
  }) async {
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      _logger.warning('SrsRepository: Cannot create SRS item while offline');
      throw Exception(
        'Cannot create SRS item while offline. Please connect to the internet.',
      );
    }

    _logger.info('SrsRepository: Creating SRS item from translation');
    final item = await _remoteDataSource.createFromTranslation(
      front: front,
      back: back,
      language: language,
      explanation: explanation,
    );
    await _localDataSource.upsertFromRemote(item.toJson());
    _logger.info('SrsRepository: SRS item created successfully');
    return item;
  }

  Future<List<SrsItem>> fetchDrillItems(String language) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        return await _remoteDataSource.fetchDrillItems(language);
      } catch (e, st) {
        _logger.warning(
          'SrsRepository: Failed to fetch drill items from backend',
          e,
          st,
        );
      }
    }

    return _localDataSource.getAllItems();
  }

  Stream<List<SrsItem>> watchDueItems() {
    return _localDataSource.watchDueItems();
  }

  Stream<List<SrsItem>> watchDueSrsItems() {
    return _localDataSource.watchDueItems();
  }

  Future<void> deleteItem(String id) async {
    _logger.info('SrsRepository: Deleting SRS item: $id locally');
    final db = _localDataSource;
    await db.deleteItem(id);
  }
}

final srsRepositoryProvider = Provider<SrsRepository>((ref) {
  return SrsRepository(
    ref,
    ref.watch(srsRemoteDataSourceProvider),
    ref.watch(srsLocalDataSourceProvider),
    ref.watch(syncRepositoryProvider),
  );
});
