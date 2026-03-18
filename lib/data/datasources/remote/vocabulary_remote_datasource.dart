import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../network/api_client.dart';

class VocabularyCounts {
  final int total;
  final int known;
  final int learning;
  final int unknown;

  VocabularyCounts({
    required this.total,
    required this.known,
    required this.learning,
    required this.unknown,
  });
}

class VocabularyPageResult {
  final Map<String, String> items;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final VocabularyCounts counts;

  VocabularyPageResult({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.counts,
  });
}

class VocabularyRemoteDataSource {
  final ApiClient _client;

  VocabularyRemoteDataSource(this._client);

  Future<Map<String, String>> getVocabulary(String language) async {
    final response = await _client.get(
      '/api/vocabulary',
      queryParameters: {'targetLanguage': language},
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = response.data;
      return data.map(
        (key, value) =>
            MapEntry(key.toLowerCase(), value.toString().toLowerCase()),
      );
    }
    throw Exception('Failed to fetch vocabulary');
  }

  Future<VocabularyPageResult> getVocabularyPage(
    String language, {
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'targetLanguage': language,
      'page': page,
      'limit': limit,
    };
    if (status != null) {
      queryParams['status'] = status;
    }

    final response = await _client.get(
      '/api/vocabulary',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as Map<String, dynamic>;
      final pagination = data['pagination'] as Map<String, dynamic>;
      final counts = data['counts'] as Map<String, dynamic>;

      return VocabularyPageResult(
        items: items.map(
          (key, value) =>
              MapEntry(key.toLowerCase(), value.toString().toLowerCase()),
        ),
        totalCount: pagination['totalCount'] as int,
        totalPages: pagination['totalPages'] as int,
        currentPage: pagination['page'] as int,
        counts: VocabularyCounts(
          total: counts['total'] as int,
          known: counts['known'] as int,
          learning: counts['learning'] as int,
          unknown: counts['unknown'] as int,
        ),
      );
    }
    throw Exception('Failed to fetch vocabulary page');
  }
}

final vocabularyRemoteDataSourceProvider = Provider<VocabularyRemoteDataSource>(
  (ref) {
    return VocabularyRemoteDataSource(ref.watch(apiClientProvider));
  },
);
