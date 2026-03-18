import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics.dart';
import 'logger_service.dart';
import '../providers/connectivity_provider.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';

class AnalyticsService {
  final Ref _ref;
  late final LoggerService _logger;
  final ApiClient _client;
  final AppDatabase _db;

  AnalyticsService(this._ref, this._client, this._db) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<AnalyticsData> fetchAnalytics(
    String targetLanguage, {
    String predictionHorizon = '3m',
  }) async {
    _logger.info(
      'AnalyticsService: Fetching main analytics for $targetLanguage',
    );

    if (!_isOnline) {
      _logger.warning('AnalyticsService: Offline, trying cache');
      final cached = await _db.getCachedAnalytics(targetLanguage);
      if (cached != null) {
        try {
          return await Isolate.run(() => AnalyticsData.fromJson(cached));
        } catch (_) {
          return AnalyticsData.fromJson(cached);
        }
      }
      throw Exception('No cached analytics available offline');
    }

    try {
      final response = await _client.get(
        '/api/analytics',
        queryParameters: {
          'targetLanguage': targetLanguage,
          'predictionHorizon': predictionHorizon,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> rawData = response.data;
        await _db.cacheAnalytics(targetLanguage, rawData);
        try {
          return await Isolate.run(() => AnalyticsData.fromJson(rawData));
        } catch (e, st) {
          _logger.warning(
            'AnalyticsService: fromJson isolate failed, falling back',
            e,
            st,
          );
          return AnalyticsData.fromJson(rawData);
        }
      }
      throw Exception('Failed to load analytics');
    } catch (e) {
      _logger.warning('AnalyticsService: API failed, trying cache: $e');
      final cached = await _db.getCachedAnalytics(targetLanguage);
      if (cached != null) {
        try {
          return await Isolate.run(() => AnalyticsData.fromJson(cached));
        } catch (_) {
          return AnalyticsData.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  Future<GoalProgress> fetchGoalProgress() async {
    _logger.info('AnalyticsService: Fetching goal progress');

    if (!_isOnline) {
      _logger.warning('AnalyticsService: Offline, cannot fetch goal progress');
      throw Exception('Goal progress requires internet connection');
    }

    final response = await _client.get('/api/user/goal-progress');

    if (response.statusCode == 200) {
      return GoalProgress.fromJson(response.data);
    }
    throw Exception('Failed to load goal progress');
  }

  Future<List<ActivityHeatmapPoint>> fetchActivityHeatmap(
    String targetLanguage, {
    int? year,
  }) async {
    _logger.info('AnalyticsService: Fetching heatmap');

    if (!_isOnline) {
      _logger.warning('AnalyticsService: Offline, cannot fetch heatmap');
      throw Exception('Activity heatmap requires internet connection');
    }

    final y = year ?? DateTime.now().year;
    final response = await _client.get(
      '/api/user/activity-stats',
      queryParameters: {
        'type': 'heatmap',
        'targetLanguage': targetLanguage,
        'year': y.toString(),
      },
    );

    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((e) => ActivityHeatmapPoint.fromJson(e)).toList();
    }
    throw Exception('Failed to load activity heatmap');
  }

  Future<List<PracticeConcept>> fetchPracticeAnalytics(
    String targetLanguage,
  ) async {
    _logger.info('AnalyticsService: Fetching practice analytics');

    if (!_isOnline) {
      _logger.warning(
        'AnalyticsService: Offline, cannot fetch practice analytics',
      );
      throw Exception('Practice analytics requires internet connection');
    }

    final response = await _client.get(
      '/api/user/practice-analytics',
      queryParameters: {'targetLanguage': targetLanguage},
    );

    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((e) => PracticeConcept.fromJson(e)).toList();
    }
    throw Exception('Failed to load practice analytics');
  }
}

final analyticsServiceProvider = Provider(
  (ref) => AnalyticsService(
    ref,
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
  ),
);
