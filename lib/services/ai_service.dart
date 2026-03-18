import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../models/translation_result.dart';
import 'logger_service.dart';
import '../providers/connectivity_provider.dart';
import '../network/api_client.dart';
import '../database/app_database.dart';

class AIService {
  final Ref _ref;
  final ApiClient _client;
  final AppDatabase _db;
  late final LoggerService _logger;

  AIService(this._ref, this._client, this._db) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

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
      return await _getOfflineTranslation(text, sourceLang, targetLang);
    }

    try {
      final response = await _client.post(
        '/api/ai/translate',
        data: {
          'text': text,
          'sourceLanguage': sourceLang,
          'targetLanguage': targetLang,
        },
      );

      _logger.debug(
        'AIService: translate response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _logger.info('AIService: Translation successful');
        return data['translatedText'];
      }

      final errorMsg = response.data['error'] ?? 'Translation failed';
      _logger.warning('AIService: Translation failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('AIService: Error during translate', e, stackTrace);

      if (_isOnline) {
        rethrow;
      }
      return await _getOfflineTranslation(text, sourceLang, targetLang);
    }
  }

  Future<String> _getOfflineTranslation(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    final sourceCode = _mapToMlKitCode(sourceLang);
    final targetCode = _mapToMlKitCode(targetLang);

    try {
      final source = _getTranslateLanguage(sourceCode);
      final target = _getTranslateLanguage(targetCode);

      final modelManager = OnDeviceTranslatorModelManager();

      final bool sourceDownloaded = await modelManager.isModelDownloaded(
        source.bcpCode,
      );
      final bool targetDownloaded = await modelManager.isModelDownloaded(
        target.bcpCode,
      );

      if (!sourceDownloaded || !targetDownloaded) {
        final missingLangs = <String>[];
        if (!sourceDownloaded) missingLangs.add(_getLanguageName(sourceCode));
        if (!targetDownloaded) missingLangs.add(_getLanguageName(targetCode));
        _logger.warning(
          'AIService: ML Models not downloaded for: ${missingLangs.join(', ')}',
        );
        return 'Translation unavailable offline.\n\nTo translate without internet, please download the ${missingLangs.join(' and ')} language model in Settings.';
      }

      final translator = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );

      final result = await translator.translateText(text);
      _logger.info('AIService: Offline ML translation successful.');

      await translator.close();

      return result;
    } catch (e) {
      _logger.warning('AIService: Offline ML translation setup failed: $e');
      return 'Translation failed offline. Please connect to the internet for translations.';
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

  String _getLanguageName(String code) {
    const Map<String, String> languageNames = {
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ru': 'Russian',
      'ar': 'Arabic',
      'en': 'English',
    };
    return languageNames[code] ?? code.toUpperCase();
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
      final response = await _client.post(
        '/api/ai/translate-breakdown',
        data: {
          'text': text,
          'sourceLanguage': sourceLang,
          'targetLanguage': targetLang,
        },
      );

      _logger.debug(
        'AIService: translateBreakdown response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List segmentsJson = data['segments'] ?? [];
        _logger.info(
          'AIService: Breakdown successful, found ${segmentsJson.length} segments',
        );
        return segmentsJson.map((s) => TranslationSegment.fromJson(s)).toList();
      }

      final errorMsg = response.data['error'] ?? 'Breakdown failed';
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
      final response = await _client.post(
        '/api/ai/contextual-translate',
        data: {
          'selectedText': selectedText,
          'context': context,
          'sourceLanguage': sourceLanguage,
          'targetLanguage': targetLanguage,
          'nativeLanguage': nativeLanguage,
        },
      );

      if (response.statusCode == 200) {
        return response.data;
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

  // NEW: Hybrid Stream Logic
  Stream<Map<String, dynamic>> streamContextualTranslation({
    required String selectedText,
    required String context,
    required String sourceLanguage,
    required String targetLanguage,
  }) async* {
    final cacheKey = '${selectedText}_${context}_$targetLanguage'.hashCode
        .toString();

    // 1. Check Local Cache (Instant)
    final cached = await _db.getCachedTranslation(cacheKey);
    if (cached != null) {
      yield {...cached, 'isFinal': true, 'source': 'cache'};
      return;
    }

    // 2. Local ML Kit Preview (Phase 1: ~100ms)
    final quickTranslation = await _getOfflineTranslation(
      selectedText,
      sourceLanguage,
      targetLanguage,
    );
    yield {
      'translation': quickTranslation,
      'explanation': 'Lexi is analyzing nuance...',
      'isFinal': false,
      'source': 'mlkit',
    };

    // 3. Remote LLM Upgrade (Phase 2: ~1-2s)
    if (_isOnline) {
      try {
        final remote = await contextualTranslate(
          selectedText: selectedText,
          context: context,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          nativeLanguage: targetLanguage,
        );
        await _db.cacheTranslation(cacheKey, remote);
        yield {...remote, 'isFinal': true, 'source': 'remote'};
      } catch (e) {
        _logger.error('Hybrid translation upgrade failed', e);
      }
    }
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
    final response = await _client.post(
      endpoint,
      data: {...context, 'chatHistory': chatHistory},
    );

    if (response.statusCode == 200) {
      return response.data['response'];
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
}

final aiServiceProvider = Provider(
  (ref) =>
      AIService(ref, ref.watch(apiClientProvider), ref.watch(databaseProvider)),
);
