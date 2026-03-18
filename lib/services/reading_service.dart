import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_models.dart';
import '../network/api_client.dart';

class ReadingService {
  final ApiClient _client;

  ReadingService(this._client);

  Future<ReadingMaterial> getMaterial(String targetLanguage) async {
    final response = await _client.get(
      '/api/reading-material',
      queryParameters: {'targetLanguage': targetLanguage},
    );

    if (response.statusCode == 200) {
      return ReadingMaterial.fromJson(response.data);
    }
    throw Exception('Failed to load reading material');
  }

  Future<ReadingTasksResponse> generateTasks({
    required String content,
    required String targetLanguage,
    required String level,
  }) async {
    final response = await _client.post(
      '/api/ai/reading-task',
      data: {
        'content': content,
        'targetLanguage': targetLanguage,
        'level': level,
      },
    );

    if (response.statusCode == 200) {
      return ReadingTasksResponse.fromJson(response.data);
    }
    throw Exception('Failed to generate reading tasks');
  }
}

final readingServiceProvider = Provider(
  (ref) => ReadingService(ref.watch(apiClientProvider)),
);
