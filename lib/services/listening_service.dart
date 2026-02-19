import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/listening_models.dart';
import '../utils/constants.dart';
import 'token_service.dart';

class ListeningService {
  final TokenService _authTokenService;

  ListeningService(this._authTokenService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Fetch Material (GET)
  Future<ListeningExercise> getExercise(String targetLanguage) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/listening-material?targetLanguage=$targetLanguage'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return ListeningExercise.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load listening exercise');
  }

  // 2. Generate Tasks (POST)
  Future<ListeningTasksResponse> generateTasks(String exerciseId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/ai/listening-task'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'listeningExerciseId': exerciseId,
      }),
    );

    if (response.statusCode == 200) {
      return ListeningTasksResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to generate listening tasks');
  }
}

final listeningServiceProvider = Provider((ref) => 
  ListeningService(ref.watch(tokenServiceProvider(TokenType.auth)))
);
