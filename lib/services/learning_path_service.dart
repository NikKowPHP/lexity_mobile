import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/learning_module.dart';
import '../utils/constants.dart';
import 'token_service.dart';
import 'logger_service.dart';

class LearningPathService {
  final Ref _ref;
  final TokenService _authTokenService;
  late final LoggerService _logger;

  LearningPathService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<LearningModule>> getPath(String language) async {
    _logger.info('LearningPathService: Fetching path for $language');
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/learning-path?targetLanguage=$language'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => LearningModule.fromJson(e)).toList();
    }
    throw Exception('Failed to load learning path');
  }

  Future<void> generateNextModule(String language) async {
    _logger.info('LearningPathService: Generating next module');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/learning-path/generate-next-module'),
      headers: await _getHeaders(),
      body: jsonEncode({'targetLanguage': language}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate next module');
    }
  }

  Future<void> updateActivity(String moduleId, String activityKey, bool isCompleted, [Map<String, dynamic>? metadata]) async {
    await http.put(
      Uri.parse('${AppConstants.baseUrl}/api/learning-path/modules/$moduleId/activity'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'activityKey': activityKey,
        'isCompleted': isCompleted,
        'metadata': metadata,
      }),
    );
  }

  Future<LearningModule> completeModule(String moduleId, {bool skip = false}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/learning-path/modules/$moduleId/complete'),
      headers: await _getHeaders(),
      body: jsonEncode({'skip': skip}),
    );

    if (response.statusCode == 200) {
      return LearningModule.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to complete module');
  }
}

final learningPathServiceProvider = Provider((ref) => 
  LearningPathService(ref, ref.watch(tokenServiceProvider(TokenType.auth)))
);
