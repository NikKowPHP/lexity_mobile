import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/reading_models.dart';
import '../utils/constants.dart';
import 'token_service.dart';

class ReadingService {
  final TokenService _authTokenService;

  ReadingService(this._authTokenService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Fetch Material (GET)
  Future<ReadingMaterial> getMaterial(String targetLanguage) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/reading-material?targetLanguage=$targetLanguage'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return ReadingMaterial.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load reading material');
  }

  // 2. Generate Tasks (POST)
  Future<ReadingTasksResponse> generateTasks({
    required String content,
    required String targetLanguage,
    required String level,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/ai/reading-task'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'content': content,
        'targetLanguage': targetLanguage,
        'level': level,
      }),
    );

    if (response.statusCode == 200) {
      return ReadingTasksResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to generate reading tasks');
  }
}

final readingServiceProvider = Provider((ref) => 
  ReadingService(ref.watch(tokenServiceProvider(TokenType.auth)))
);
