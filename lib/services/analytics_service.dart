import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../models/analytics.dart';
import 'logger_service.dart';
import '../utils/constants.dart';
import '../providers/connectivity_provider.dart';
import '../database/app_database.dart';

class AnalyticsService {
  final Ref _ref;
  late final LoggerService _logger;
  final TokenService _authTokenService;
  final AppDatabase _db;

  AnalyticsService(this._ref, this._authTokenService, this._db) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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
        return AnalyticsData.fromJson(cached);
      }
      throw Exception('No cached analytics available offline');
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/api/analytics?targetLanguage=$targetLanguage&predictionHorizon=$predictionHorizon',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _db.cacheAnalytics(targetLanguage, data);
        return AnalyticsData.fromJson(data);
      }
      throw Exception('Failed to load analytics');
    } catch (e) {
      _logger.warning('AnalyticsService: API failed, trying cache: $e');
      final cached = await _db.getCachedAnalytics(targetLanguage);
      if (cached != null) {
        return AnalyticsData.fromJson(cached);
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

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/user/goal-progress'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return GoalProgress.fromJson(jsonDecode(response.body));
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
    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/user/activity-stats?type=heatmap&targetLanguage=$targetLanguage&year=$y',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
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

    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/user/practice-analytics?targetLanguage=$targetLanguage',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => PracticeConcept.fromJson(e)).toList();
    }
    throw Exception('Failed to load practice analytics');
  }
}

final analyticsServiceProvider = Provider(
  (ref) => AnalyticsService(
    ref,
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(databaseProvider),
  ),
);
