import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../network/api_client.dart';
import '../../../models/srs_item.dart';

class SrsRemoteDataSource {
  final ApiClient _client;

  SrsRemoteDataSource(this._client);

  Future<List<SrsItem>> fetchDeck(String language) async {
    final response = await _client.get(
      '/api/srs/deck',
      queryParameters: {'targetLanguage': language},
    );
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((item) => SrsItem.fromJson(item)).toList();
    }
    throw Exception('Failed to fetch SRS deck');
  }

  Future<List<SrsItem>> fetchAllItems(String language) async {
    final response = await _client.get(
      '/api/srs/all',
      queryParameters: {'targetLanguage': language},
    );
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((item) => SrsItem.fromJson(item)).toList();
    }
    throw Exception('Failed to fetch all SRS items');
  }

  Future<SrsItem> createFromTranslation({
    required String front,
    required String back,
    required String language,
    String? explanation,
  }) async {
    final response = await _client.post(
      '/api/srs/create-from-translation',
      data: {
        'frontContent': front,
        'backContent': back,
        'targetLanguage': language,
        'explanation': explanation ?? '',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return SrsItem.fromJson(response.data);
    }
    final body = response.data;
    final String errorMsg = body is Map && body.containsKey('error')
        ? body['error'].toString()
        : body.toString();
    throw Exception(errorMsg);
  }

  Future<List<SrsItem>> fetchDrillItems(String language) async {
    final response = await _client.get(
      '/api/srs/drill',
      queryParameters: {'targetLanguage': language},
    );
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((item) => SrsItem.fromJson(item)).toList();
    }
    throw Exception('Failed to fetch drill items');
  }
}

final srsRemoteDataSourceProvider = Provider<SrsRemoteDataSource>((ref) {
  return SrsRemoteDataSource(ref.watch(apiClientProvider));
});
