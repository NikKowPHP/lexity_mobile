import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/auth_service.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../models/analytics.dart';
import 'logger_service.dart';

class AnalyticsService {
  final Ref _ref;
  late final LoggerService _logger;
  final TokenService _authTokenService;
  AnalyticsService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

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
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/analytics?targetLanguage=$targetLanguage&predictionHorizon=$predictionHorizon',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return AnalyticsData.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load analytics');
  }

  Future<GoalProgress> fetchGoalProgress() async {
    _logger.info('AnalyticsService: Fetching goal progress');
    final response = await http.get(
      Uri.parse('$baseUrl/api/user/goal-progress'),
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
    final y = year ?? DateTime.now().year;
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/user/activity-stats?type=heatmap&targetLanguage=$targetLanguage&year=$y',
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
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/user/practice-analytics?targetLanguage=$targetLanguage',
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
  (ref) =>
      AnalyticsService(ref, ref.watch(tokenServiceProvider(TokenType.auth))),
);
