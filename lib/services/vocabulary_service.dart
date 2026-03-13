import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../utils/constants.dart';

class VocabularyService {
  final TokenService _authTokenService;

  VocabularyService(this._authTokenService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> getVocabulary(String language) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/vocabulary?targetLanguage=$language'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      // Map the dynamic JSON object to a lowercase Map<String, String>
      return data.map((key, value) => 
        MapEntry(key.toLowerCase(), value.toString().toLowerCase()));
    }
    return {};
  }

  Future<void> updateStatus(String word, String status, String language) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/vocabulary'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'targetLanguage': language,
        'words': [word.toLowerCase()], // Backend expects an array of words
        'status': status.toUpperCase(), // Backend expects uppercase enum
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update vocabulary status');
    }
  }

  Future<void> markBatchKnown(List<String> words, String language) async {
    await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/vocabulary/batch-known'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'words': words,
        'targetLanguage': language,
      }),
    );
  }
}

final vocabularyServiceProvider = Provider((ref) => VocabularyService(ref.watch(tokenServiceProvider(TokenType.auth))));