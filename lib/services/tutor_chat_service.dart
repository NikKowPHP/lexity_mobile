import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../services/logger_service.dart';
import '../providers/connectivity_provider.dart';

class TutorChatService {
  final Ref _ref;
  final ApiClient _client;
  late final LoggerService _logger;

  TutorChatService(this._ref, this._client) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<String> getTutorResponse({
    required String endpoint,
    required Map<String, dynamic> context,
    required List<Map<String, String>> chatHistory,
  }) async {
    if (!_isOnline) {
      throw Exception('Tutor requires internet connection');
    }

    final response = await _client.post(
      endpoint,
      data: {...context, 'chatHistory': chatHistory},
    );

    if (response.statusCode == 200) {
      return response.data['response'];
    }
    throw Exception('Tutor failed to respond');
  }
}

final tutorChatServiceProvider = Provider(
  (ref) => TutorChatService(ref, ref.watch(apiClientProvider)),
);
