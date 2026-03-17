import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/learning_module.dart';
import '../utils/constants.dart';
import 'token_service.dart';
import 'logger_service.dart';
import '../providers/connectivity_provider.dart';
import '../database/app_database.dart';

class LearningPathService {
  final Ref _ref;
  final TokenService _authTokenService;
  final AppDatabase _db;
  late final LoggerService _logger;

  LearningPathService(this._ref, this._authTokenService, this._db) {
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

  Future<List<LearningModule>> getPath(String language) async {
    _logger.info('LearningPathService: Fetching path for $language');

    if (!_isOnline) {
      _logger.warning('LearningPathService: Offline, trying cache');
      final cached = await _db.getCachedLearningModules(language);
      if (cached.isNotEmpty) {
        return cached.map((e) => LearningModule.fromJson(e)).toList();
      }
      throw Exception('No cached learning path available offline');
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/api/learning-path?targetLanguage=$language',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        await _db.cacheLearningModules(
          language,
          data.cast<Map<String, dynamic>>(),
        );
        return data.map((e) => LearningModule.fromJson(e)).toList();
      }
      throw Exception('Failed to load learning path');
    } catch (e) {
      _logger.warning('LearningPathService: API failed, trying cache: $e');
      final cached = await _db.getCachedLearningModules(language);
      if (cached.isNotEmpty) {
        return cached.map((e) => LearningModule.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<void> generateNextModule(String language) async {
    _logger.info('LearningPathService: Generating next module');

    if (!_isOnline) {
      throw Exception('Cannot generate new module while offline');
    }

    final response = await http.post(
      Uri.parse(
        '${AppConstants.baseUrl}/api/learning-path/generate-next-module',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({'targetLanguage': language}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate next module');
    }
  }

  Future<void> updateActivity(
    String moduleId,
    String activityKey,
    bool isCompleted, [
    Map<String, dynamic>? metadata,
  ]) async {
    if (!_isOnline) {
      throw Exception('Cannot update activity while offline');
    }

    await http.put(
      Uri.parse(
        '${AppConstants.baseUrl}/api/learning-path/modules/$moduleId/activity',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({
        'activityKey': activityKey,
        'isCompleted': isCompleted,
        'metadata': metadata,
      }),
    );
  }

  Future<LearningModule> completeModule(
    String moduleId, {
    bool skip = false,
  }) async {
    if (!_isOnline) {
      throw Exception('Cannot complete module while offline');
    }

    final response = await http.post(
      Uri.parse(
        '${AppConstants.baseUrl}/api/learning-path/modules/$moduleId/complete',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({'skip': skip}),
    );

    if (response.statusCode == 200) {
      return LearningModule.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to complete module');
  }
}

final learningPathServiceProvider = Provider(
  (ref) => LearningPathService(
    ref,
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(databaseProvider),
  ),
);
