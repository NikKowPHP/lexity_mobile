import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../network/api_client.dart';

class SyncDeltaResponse {
  final String syncTimestamp;
  final List<dynamic> changes;
  final bool hasMore;

  SyncDeltaResponse({
    required this.syncTimestamp,
    required this.changes,
    required this.hasMore,
  });

  factory SyncDeltaResponse.fromJson(Map<String, dynamic> json) {
    return SyncDeltaResponse(
      syncTimestamp: json['sync_timestamp'] as String,
      changes: json['changes'] as List<dynamic>? ?? [],
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class SyncRemoteDataSource {
  final ApiClient _client;

  SyncRemoteDataSource(this._client);

  Future<SyncDeltaResponse> fetchDelta(String? since) async {
    final queryParams = <String, dynamic>{};
    if (since != null) queryParams['since'] = since;

    final response = await _client.get(
      '/api/sync/delta',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode == 200) {
      return SyncDeltaResponse.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Delta sync failed: ${response.statusCode}');
  }
}

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>((ref) {
  return SyncRemoteDataSource(ref.watch(apiClientProvider));
});
