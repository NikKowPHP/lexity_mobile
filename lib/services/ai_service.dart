import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import '../models/translation_result.dart';
import 'logger_service.dart';
import '../utils/constants.dart';

class AIService {
  final Ref _ref;

  late final LoggerService _logger;
  final TokenService _authTokenService;
  AIService(this._ref, this._authTokenService) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Call 1: Fast Full Translation
  Future<String> translate(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    _logger.info(
      'AIService: Requesting translation from $sourceLang to $targetLang',
    );
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
      rethrow;
    }
  }

  // Call 2: Detailed Breakdown
  Future<List<TranslationSegment>> translateBreakdown(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    _logger.info(
      'AIService: Requesting breakdown from $sourceLang to $targetLang',
    );
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

  // Call 3: Contextual Translation (for reading tooltips)
  Future<Map<String, dynamic>> contextualTranslate({
    required String selectedText,
    required String context,
    required String sourceLanguage,
    required String targetLanguage,
    required String nativeLanguage,
  }) async {
    _logger.info('AIService: Requesting contextual translation');
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
      rethrow;
    }
  }
}

final aiServiceProvider = Provider(
  (ref) => AIService(ref, ref.watch(tokenServiceProvider(TokenType.auth))),
);
