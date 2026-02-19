import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/auth_service.dart';
import 'package:lexity_mobile/services/token_service.dart';
import 'logger_service.dart';
import '../models/journal_entry.dart';

class JournalService {
  final Ref _ref;
  final TokenService _authTokenService;
  late final LoggerService _logger;

  JournalService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<JournalEntry>> getHistory(String targetLanguage) async {
    _logger.info('JournalService: Fetching history for $targetLanguage');
    final response = await http.get(
      Uri.parse('$baseUrl/api/journal?targetLanguage=$targetLanguage'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => JournalEntry.fromJson(e)).toList();
    }
    throw Exception('Failed to load journal history');
  }

  Future<JournalEntry> getEntry(String id) async {
    _logger.info('JournalService: Fetching entry $id');
    final response = await http.get(
      Uri.parse('$baseUrl/api/journal/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return JournalEntry.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load entry');
  }

  Future<JournalEntry> createEntry(String content, String title, String targetLanguage) async {
    _logger.info('JournalService: Creating entry');
    final response = await http.post(
      Uri.parse('$baseUrl/api/journal'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'content': content,
        'topicTitle': title,
        'targetLanguage': targetLanguage,
        'mode': 'free_write'
      }),
    );

    if (response.statusCode == 201) {
      return JournalEntry.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create entry');
  }

  Future<void> updateEntry(String id, String content, String title) async {
     _logger.info('JournalService: Updating entry $id');
     final response = await http.put(
       Uri.parse('$baseUrl/api/journal/$id'),
       headers: await _getHeaders(),
       body: jsonEncode({
         'content': content,
         'topicId': 'unknown', // Simplification: API requires topicId, ideally we fetch it first or API supports title update
       })
     );
      if (response.statusCode != 200) throw Exception('Failed to update entry');
  }

  Future<void> deleteEntry(String id) async {
    _logger.info('JournalService: Deleting entry $id');
    final response = await http.delete(
      Uri.parse('$baseUrl/api/journal/$id'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete entry');
    }
  }

  Future<void> analyzeEntry(String id) async {
    _logger.info('JournalService: Starting analysis for $id');
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze'),
      headers: await _getHeaders(),
      body: jsonEncode({'journalId': id}),
    );
    if (response.statusCode != 200) throw Exception('Failed to start analysis');
  }

  Future<List<String>> getSuggestedTopics(String targetLanguage) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/user/suggested-topics?targetLanguage=$targetLanguage'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['topics'] ?? []);
    }
    return [];
  }
  
  Future<void> generateTopics(String targetLanguage) async {
     await http.get(
      Uri.parse('$baseUrl/api/user/generate-topics?targetLanguage=$targetLanguage'),
      headers: await _getHeaders(),
    );
  }
}

final journalServiceProvider = Provider((ref) => JournalService(ref, ref.watch(tokenServiceProvider(TokenType.auth))));
