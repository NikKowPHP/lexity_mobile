import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../models/translation_result.dart';
import 'logger_service.dart';
import '../utils/constants.dart';
import '../providers/connectivity_provider.dart';

class AIService {
  final Ref _ref;
  late final LoggerService _logger;
  final TokenService _authTokenService;

  AIService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> translate(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    _logger.info(
      'AIService: Requesting translation from $sourceLang to $targetLang',
    );

    if (!_isOnline) {
      _logger.warning(
        'AIService: Offline, returning offline translation fallback',
      );
      return _getOfflineTranslation(text, sourceLang, targetLang);
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/ai/translate'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'text': text,
          'sourceLanguage': sourceLang,
          'targetLanguage': targetLang,
        }),
      );

      _logger.debug(
        'AIService: translate response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('AIService: Translation successful');
        return data['translatedText'];
      }

      final errorMsg =
          jsonDecode(response.body)['error'] ?? 'Translation failed';
      _logger.warning('AIService: Translation failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('AIService: Error during translate', e, stackTrace);

      if (_isOnline) {
        rethrow;
      }
      return _getOfflineTranslation(text, sourceLang, targetLang);
    }
  }

  String _getOfflineTranslation(
    String text,
    String sourceLang,
    String targetLang,
  ) {
    final sourceCode = _mapToMlKitCode(sourceLang);
    final targetCode = _mapToMlKitCode(targetLang);

    try {
      final translator = OnDeviceTranslator(
        sourceLanguage: _getTranslateLanguage(sourceCode),
        targetLanguage: _getTranslateLanguage(targetCode),
      );

      translator
          .translateText(text)
          .then((result) {
            _logger.info(
              'AIService: Offline ML translation successful: $result',
            );
          })
          .catchError((e) {
            _logger.warning('AIService: Offline ML translation failed: $e');
          });

      return '[$targetLang offline: $text]';
    } catch (e) {
      _logger.warning('AIService: Offline ML translation setup failed: $e');
      return '[$targetLang translation unavailable offline: "$text"]';
    }
  }

  TranslateLanguage _getTranslateLanguage(String code) {
    switch (code) {
      case 'es':
        return TranslateLanguage.spanish;
      case 'fr':
        return TranslateLanguage.french;
      case 'de':
        return TranslateLanguage.german;
      case 'it':
        return TranslateLanguage.italian;
      case 'pt':
        return TranslateLanguage.portuguese;
      case 'zh':
        return TranslateLanguage.chinese;
      case 'ja':
        return TranslateLanguage.japanese;
      case 'ko':
        return TranslateLanguage.korean;
      case 'ru':
        return TranslateLanguage.russian;
      case 'ar':
        return TranslateLanguage.arabic;
      case 'en':
        return TranslateLanguage.english;
      default:
        return TranslateLanguage.english;
    }
  }

  String _mapToMlKitCode(String language) {
    const Map<String, String> languageMapping = {
      'spanish': 'es',
      'french': 'fr',
      'german': 'de',
      'italian': 'it',
      'portuguese': 'pt',
      'chinese': 'zh',
      'japanese': 'ja',
      'korean': 'ko',
      'russian': 'ru',
      'arabic': 'ar',
      'english': 'en',
    };
    return languageMapping[language.toLowerCase()] ?? language.toLowerCase();
  }

  Future<List<TranslationSegment>> translateBreakdown(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    _logger.info(
      'AIService: Requesting breakdown from $sourceLang to $targetLang',
    );

    if (!_isOnline) {
      _logger.warning('AIService: Offline, breakdown requires internet');
      throw Exception('Breakdown requires internet connection');
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/ai/translate-breakdown'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'text': text,
          'sourceLanguage': sourceLang,
          'targetLanguage': targetLang,
        }),
      );

      _logger.debug(
        'AIService: translateBreakdown response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List segmentsJson = data['segments'] ?? [];
        _logger.info(
          'AIService: Breakdown successful, found ${segmentsJson.length} segments',
        );
        return segmentsJson.map((s) => TranslationSegment.fromJson(s)).toList();
      }

      final errorMsg = jsonDecode(response.body)['error'] ?? 'Breakdown failed';
      _logger.warning('AIService: Breakdown failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error(
        'AIService: Error during translateBreakdown',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> contextualTranslate({
    required String selectedText,
    required String context,
    required String sourceLanguage,
    required String targetLanguage,
    required String nativeLanguage,
  }) async {
    _logger.info('AIService: Requesting contextual translation');

    if (!_isOnline) {
      _logger.warning('AIService: Offline, returning offline fallback');
      return _getOfflineContextualTranslation(
        selectedText,
        context,
        sourceLanguage,
        targetLanguage,
        nativeLanguage,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/ai/contextual-translate'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'selectedText': selectedText,
          'context': context,
          'sourceLanguage': sourceLanguage,
          'targetLanguage': targetLanguage,
          'nativeLanguage': nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Contextual translation failed');
    } catch (e, stackTrace) {
      _logger.error(
        'AIService: Error during contextualTranslate',
        e,
        stackTrace,
      );

      if (_isOnline) {
        rethrow;
      }
      return _getOfflineContextualTranslation(
        selectedText,
        context,
        sourceLanguage,
        targetLanguage,
        nativeLanguage,
      );
    }
  }

  Map<String, dynamic> _getOfflineContextualTranslation(
    String selectedText,
    String context,
    String sourceLanguage,
    String targetLanguage,
    String nativeLanguage,
  ) {
    return {
      'translation': '[$targetLanguage translation unavailable offline]',
      'explanation':
          'Offline mode: Context-aware translation requires internet connection.',
      'isOffline': true,
    };
  }

  Future<String> getTutorResponse({
    required String endpoint,
    required Map<String, dynamic> context,
    required List<Map<String, String>> chatHistory,
  }) async {
    if (!_isOnline) {
      _logger.warning('AIService: Offline, Tutor requires internet');
      throw Exception('Tutor requires internet connection');
    }

    _logger.info('AIService: Requesting tutor response from $endpoint');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode({...context, 'chatHistory': chatHistory}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['response'];
    }
    throw Exception('Tutor failed to respond');
  }

  Future<List<String>> generateStuckWriterSuggestions(
    String title,
    String content,
    String language,
  ) async {
    if (!_isOnline) {
      _logger.warning('AIService: Offline, returning offline suggestions');
      return _getOfflineSuggestions();
    }

    _logger.info('AIService: Requesting stuck writer suggestions');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/ai/stuck-writer'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'title': title,
        'content': content,
        'targetLanguage': language,
      }),
    );

    if (response.statusCode == 200) {
      final List suggestions = jsonDecode(response.body)['suggestions'] ?? [];
      return suggestions.map((s) => s.toString()).toList();
    }
    return _getOfflineSuggestions();
  }

  List<String> _getOfflineSuggestions() {
    return [
      'Try writing about how you feel today.',
      'What did you eat for breakfast?',
      'Describe your surroundings.',
      'Write about a recent memory.',
    ];
  }

  Future<List<String>> getStuckSpeakerSuggestions(
    List<int> audioBytes,
    String language,
  ) async {
    if (!_isOnline) {
      _logger.warning('AIService: Offline, returning offline suggestions');
      return [
        "Try saying: 'I am practicing my speaking.'",
        "Describe your day.",
      ];
    }

    _logger.info('AIService: Requesting stuck speaker suggestions');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/ai/stuck-speaker'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'audioBase64': base64Encode(audioBytes),
        'targetLanguage': language,
      }),
    );

    if (response.statusCode == 200) {
      final List suggestions = jsonDecode(response.body)['suggestions'] ?? [];
      return suggestions.map((s) => s.toString()).toList();
    }
    return ["Try saying: 'I am practicing my speaking.'"];
  }
}

final aiServiceProvider = Provider(
  (ref) => AIService(ref, ref.watch(tokenServiceProvider(TokenType.auth))),
);
