import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import 'logger_service.dart';
import '../models/journal_entry.dart';
import '../models/writing_aids.dart';
import '../utils/constants.dart';

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
      Uri.parse(
        '${AppConstants.baseUrl}/api/journal?targetLanguage=$targetLanguage',
      ),
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
      Uri.parse('${AppConstants.baseUrl}/api/journal/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return JournalEntry.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load entry');
  }

  // MODIFIED: Accept optional moduleId
  Future<JournalEntry> createEntry(
    String content,
    String title,
    String targetLanguage, {
    String? moduleId,
  }) async {
    _logger.info('JournalService: Creating entry');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/journal'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'content': content,
        'topicTitle': title,
        'targetLanguage': targetLanguage,
        'mode': 'free_write',
        'moduleId': moduleId, // Include moduleId if present
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
      Uri.parse('${AppConstants.baseUrl}/api/journal/$id'),
       headers: await _getHeaders(),
       body: jsonEncode({
         'content': content,
        'topicId':
            title, // Note: Web API might expect ID, but here we pass title/ID logic based on your implementation
       })
     );
      if (response.statusCode != 200) throw Exception('Failed to update entry');
  }

  // NEW METHODS FOR AUDIO UPLOAD
  Future<void> _uploadFileToSupabase(String signedUrl, File file) async {
    final bytes = await file.readAsBytes();
    // Using simple PUT as required by Supabase Storage signed URLs
    final response = await http.put(
      Uri.parse(signedUrl),
      headers: {'Content-Type': 'audio/webm'}, // Adjust mime type as needed
      body: bytes,
    );
    if (response.statusCode != 200) throw Exception('Failed to upload file');
  }

  Future<JournalEntry> createAudioEntry(
    String filePath,
    String targetLanguage, {
    String? moduleId,
  }) async {
    _logger.info('JournalService: Starting audio journal creation');

    final file = File(filePath);
    final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';

    // 1. Get Signed URL
    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/journal/generate-upload-url?filename=$filename',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to generate upload URL');
    }
    final data = jsonDecode(response.body);
    var signedUrl = data['signedUrl'] as String;
    final storagePath = data['path'];

    if (signedUrl.startsWith('/')) {
      signedUrl = '${AppConstants.baseUrl}$signedUrl';
    }

    // 2. Upload Binary
    await _uploadFileToSupabase(signedUrl, file);

    // 3. Create Journal Record
    final createResponse = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/journal/audio'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'path': storagePath,
        'targetLanguage': targetLanguage,
        'moduleId': moduleId,
        'aidsUsage': [],
      }),
    );

    if (createResponse.statusCode == 201) {
      return JournalEntry.fromJson(jsonDecode(createResponse.body));
    }
    throw Exception('Failed to create audio journal record');
  }

  Future<void> deleteEntry(String id) async {
    _logger.info('JournalService: Deleting entry $id');
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/api/journal/$id'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete entry');
    }
  }

  Future<void> analyzeEntry(String id) async {
    _logger.info('JournalService: Starting analysis for $id');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/analyze'),
      headers: await _getHeaders(),
      body: jsonEncode({'journalId': id}),
    );
    if (response.statusCode != 200) throw Exception('Failed to start analysis');
  }

  Future<List<String>> getSuggestedTopics(String targetLanguage) async {
    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/user/suggested-topics?targetLanguage=$targetLanguage',
      ),
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
      Uri.parse(
        '${AppConstants.baseUrl}/api/user/generate-topics?targetLanguage=$targetLanguage',
      ),
      headers: await _getHeaders(),
    );
  }

  Future<WritingAids> getWritingAids(
    String topic,
    String targetLanguage,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/journal/helpers'),
      headers: await _getHeaders(),
      body: jsonEncode({'topic': topic, 'targetLanguage': targetLanguage}),
    );

    if (response.statusCode == 200) {
      return WritingAids.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load writing aids');
  }
}

final journalServiceProvider = Provider((ref) => JournalService(ref, ref.watch(tokenServiceProvider(TokenType.auth))));
