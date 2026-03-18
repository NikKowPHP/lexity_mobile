import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../network/api_client.dart';

class JournalRemoteDataSource {
  final ApiClient _client;

  JournalRemoteDataSource(this._client);

  Future<List<Map<String, dynamic>>> getHistory(String targetLanguage) async {
    final response = await _client.get(
      '/api/journal',
      queryParameters: {'targetLanguage': targetLanguage},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    throw Exception('Failed to fetch journal history');
  }

  Future<Map<String, dynamic>> getEntry(String id) async {
    final response = await _client.get('/api/journal/$id');
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch journal entry');
  }

  Future<void> updateEntry(String id, String content, String topicId) async {
    final response = await _client.put(
      '/api/journal/$id',
      data: {'content': content, 'topicId': topicId},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update entry');
    }
  }

  Future<Map<String, dynamic>> generateUploadUrl(String filename) async {
    final response = await _client.get(
      '/api/journal/generate-upload-url',
      queryParameters: {'filename': filename},
    );
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to generate upload URL');
  }

  Future<void> uploadFile(
    String signedUrl,
    List<int> bytes,
    String contentType,
  ) async {
    final response = await _client.dio.put(
      signedUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to upload file');
    }
  }

  Future<Map<String, dynamic>> createAudioEntry({
    required String path,
    required String targetLanguage,
    String? moduleId,
  }) async {
    final response = await _client.post(
      '/api/journal/audio',
      data: {
        'path': path,
        'targetLanguage': targetLanguage,
        'moduleId': moduleId,
        'aidsUsage': [],
      },
    );
    if (response.statusCode == 201) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to create audio journal record');
  }

  Future<void> analyzeEntry(String journalId) async {
    final response = await _client.post(
      '/api/analyze',
      data: {'journalId': journalId},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to start analysis');
    }
  }

  Future<List<String>> getSuggestedTopics(String targetLanguage) async {
    final response = await _client.get(
      '/api/user/suggested-topics',
      queryParameters: {'targetLanguage': targetLanguage},
    );
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return List<String>.from(data['topics'] ?? []);
    }
    return [];
  }

  Future<void> generateTopics(String targetLanguage) async {
    await _client.get(
      '/api/user/generate-topics',
      queryParameters: {'targetLanguage': targetLanguage},
    );
  }

  Future<Map<String, dynamic>> getWritingAids(
    String topic,
    String targetLanguage,
  ) async {
    final response = await _client.post(
      '/api/journal/helpers',
      data: {'topic': topic, 'targetLanguage': targetLanguage},
    );
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to load writing aids');
  }
}

final journalRemoteDataSourceProvider = Provider<JournalRemoteDataSource>((
  ref,
) {
  return JournalRemoteDataSource(ref.watch(apiClientProvider));
});
