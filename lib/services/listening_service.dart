import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listening_models.dart';
import '../network/api_client.dart';

class ListeningService {
  final ApiClient _client;

  ListeningService(this._client);

  Future<ListeningExercise> getExercise(String targetLanguage) async {
    final response = await _client.get(
      '/api/listening-material',
      queryParameters: {'targetLanguage': targetLanguage},
    );

    if (response.statusCode == 200) {
      return ListeningExercise.fromJson(response.data);
    }
    throw Exception('Failed to load listening exercise');
  }

  Future<ListeningTasksResponse> generateTasks(String exerciseId) async {
    final response = await _client.post(
      '/api/ai/listening-task',
      data: {'listeningExerciseId': exerciseId},
    );

    if (response.statusCode == 200) {
      return ListeningTasksResponse.fromJson(response.data);
    }
    throw Exception('Failed to generate listening tasks');
  }
}

final listeningServiceProvider = Provider(
  (ref) => ListeningService(ref.watch(apiClientProvider)),
);
