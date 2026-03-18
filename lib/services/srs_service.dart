import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/srs_item.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import 'logger_service.dart';
import '../network/api_client.dart';

class SrsService {
  final Ref _ref;
  final ApiClient _client;
  final AppDatabase _db;
  final SyncRepository _syncRepo;
  late final LoggerService _logger;

  SrsService(this._ref, this._client, this._db, this._syncRepo) {
    _logger = _ref.read(loggerProvider);
  }

  Future<List<SrsItem>> fetchDeck(String language) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await _client.get(
          '/api/srs/deck',
          queryParameters: {'targetLanguage': language},
        );

        if (response.statusCode == 200) {
          final List data = response.data;
          _logger.info(
            'SrsService: Deck fetched from backend, found ${data.length} items',
          );

          for (final item in data) {
            await _upsertSrsItemLocal(item);
          }

          return data.map((item) => SrsItem.fromJson(item)).toList();
        }
      } catch (e, st) {
        _logger.warning(
          'SrsService: Failed to fetch from backend, falling back to local',
          e,
          st,
        );
      }
    }

    return _getLocalDueItems();
  }

  Future<List<SrsItem>> _getLocalDueItems() async {
    final items = await _db.getDueSrsItems();
    return items.map((map) => _srsItemFromDb(map)).toList();
  }

  Future<void> _upsertSrsItemLocal(Map<String, dynamic> data) async {
    final nextReview = data['nextReviewDate'] != null
        ? DateTime.parse(data['nextReviewDate']).millisecondsSinceEpoch
        : DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;

    await _db.insertSrsItem({
      'id': data['id'],
      'front': data['frontContent'] ?? '',
      'back': data['backContent'] ?? '',
      'context': data['context'],
      'type': data['type'] ?? 'TRANSLATION',
      'next_review_date': nextReview,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  SrsItem _srsItemFromDb(Map<String, dynamic> map) {
    return SrsItem(
      id: map['id'] as String,
      front: map['front'] as String,
      back: map['back'] as String,
      context: map['context'] as String?,
      type: map['type'] as String? ?? 'TRANSLATION',
    );
  }

  Future<void> reviewItem(String id, int quality) async {
    _logger.info(
      'SrsService: Processing review for item: $id, quality: $quality locally',
    );

    final nextReviewDate = _calculateNextReview(quality);

    await _db.updateSrsItemReviewDate(id, nextReviewDate);

    await _syncRepo.enqueueSrsReview(id, nextReviewDate);

    _logger.info('SrsService: Review queued for sync for item: $id');
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

  Future<void> createFromTranslation({
    required String front,
    required String back,
    required String language,
    String? explanation,
  }) async {
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      _logger.warning('SrsService: Cannot create SRS item while offline');
      throw Exception(
        'Cannot create SRS item while offline. Please connect to the internet.',
      );
    }

    _logger.info('SrsService: Creating SRS item from translation');
    try {
      final response = await _client.post(
        '/api/srs/create-from-translation',
        data: {
          'frontContent': front,
          'backContent': back,
          'targetLanguage': language,
          'explanation': explanation ?? "",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        await _upsertSrsItemLocal(data);
        _logger.info('SrsService: SRS item created successfully');
        return;
      }

      final dynamic body = response.data;
      final String errorMsg = body is Map && body.containsKey('error')
          ? body['error'].toString()
          : body.toString();
      throw Exception(errorMsg);
    } catch (e, st) {
      _logger.error('SrsService: Error in createFromTranslation', e, st);
      rethrow;
    }
  }

  Future<List<SrsItem>> fetchDrillItems(String language) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await _client.get(
          '/api/srs/drill',
          queryParameters: {'targetLanguage': language},
        );

        if (response.statusCode == 200) {
          final List data = response.data;
          return data.map((item) => SrsItem.fromJson(item)).toList();
        }
      } catch (e, st) {
        _logger.warning(
          'SrsService: Failed to fetch drill items from backend',
          e,
          st,
        );
      }
    }

    final items = await _db.getAllSrsItems();
    return items.map((map) => _srsItemFromDb(map)).toList();
  }

  Future<void> deleteItem(String id) async {
    _logger.info('SrsService: Deleting SRS item: $id locally');
  }

  Stream<List<SrsItem>> watchDueSrsItems() {
    return _db.watchDueSrsItems().map(
      (items) => items.map((map) => _srsItemFromDb(map)).toList(),
    );
  }

  Future<List<SrsItem>> fetchAllItems(String language) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await _client.get(
          '/api/srs/all',
          queryParameters: {'targetLanguage': language},
        );

        if (response.statusCode == 200) {
          final List data = response.data;
          for (final item in data) {
            await _upsertSrsItemLocal(item);
          }
          final List<dynamic> rawData = data;
          try {
            return await Isolate.run(
              () => rawData
                  .map((item) => SrsItem.fromJson(item as Map<String, dynamic>))
                  .toList(),
            );
          } catch (e, st) {
            _logger.error('SrsService: fetchAllItems isolate failed', e, st);
            return rawData
                .map((item) => SrsItem.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e, st) {
        _logger.warning(
          'SrsService: Failed to fetch all items from backend',
          e,
          st,
        );
      }
    }

    return _getLocalAllItems();
  }

  Future<List<SrsItem>> _getLocalAllItems() async {
    final items = await _db.getAllSrsItems();
    return items.map((map) => _srsItemFromDb(map)).toList();
  }
}

final srsServiceProvider = Provider(
  (ref) => SrsService(
    ref,
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
    ref.watch(syncRepositoryProvider),
  ),
);
