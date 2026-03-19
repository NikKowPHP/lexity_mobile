import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../services/logger_service.dart';
import '../providers/connectivity_provider.dart';

class WritingAssistService {
  final Ref _ref;
  final ApiClient _client;
  late final LoggerService _logger;

  WritingAssistService(this._ref, this._client) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<List<String>> generateStuckWriterSuggestions(
    String title,
    String content,
    String language,
  ) async {
    if (!_isOnline) {
      return _getOfflineSuggestions();
    }

    final response = await _client.post(
      '/api/ai/stuck-writer',
      data: {'title': title, 'content': content, 'targetLanguage': language},
    );

    if (response.statusCode == 200) {
      final List suggestions = response.data['suggestions'] ?? [];
      return suggestions.map((s) => s.toString()).toList();
    }
    return _getOfflineSuggestions();
  }

  Future<List<String>> getStuckSpeakerSuggestions(
    List<int> audioBytes,
    String language,
  ) async {
    if (!_isOnline) {
      return [
        "Try saying: 'I am practicing my speaking.'",
        "Describe your day.",
      ];
    }

    final response = await _client.post(
      '/api/ai/stuck-speaker',
      data: {
        'audioBase64': base64Encode(audioBytes),
        'targetLanguage': language,
      },
    );

    if (response.statusCode == 200) {
      final List suggestions = response.data['suggestions'] ?? [];
      return suggestions.map((s) => s.toString()).toList();
    }
    return ["Try saying: 'I am practicing my speaking.'"];
  }

  List<String> _getOfflineSuggestions() {
    return [
      'Try writing about how you feel today.',
      'What did you eat for breakfast?',
      'Describe your surroundings.',
      'Write about a recent memory.',
    ];
  }
}

final writingAssistServiceProvider = Provider(
  (ref) => WritingAssistService(ref, ref.watch(apiClientProvider)),
);
