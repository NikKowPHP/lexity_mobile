import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../network/api_client.dart';
import '../database/app_database.dart';
import '../services/logger_service.dart';
import '../providers/connectivity_provider.dart';
import '../models/translation_result.dart';

class TranslationService {
  final Ref _ref;
  final ApiClient _client;
  final AppDatabase _db;
  late final LoggerService _logger;

  TranslationService(this._ref, this._client, this._db) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<String> translate(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    _logger.info(
      'TranslationService: Requesting translation from $sourceLang to $targetLang',
    );

    if (!_isOnline) {
      _logger.warning(
        'TranslationService: Offline, returning offline translation fallback',
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

      if (response.statusCode == 200) {
        return response.data['translatedText'];
      }

      final errorMsg = response.data['error'] ?? 'Translation failed';
      throw Exception(errorMsg);
    } catch (e, st) {
      _logger.error('TranslationService: Error during translate', e, st);
      if (_isOnline) rethrow;
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
        return 'Translation unavailable offline.\n\nTo translate without internet, please download the ${missingLangs.join(' and ')} language model.';
      }

      final translator = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );

      final result = await translator.translateText(text);
      await translator.close();
      return result;
    } catch (e) {
      return 'Translation failed offline. Please connect to the internet.';
    }
  }

  Future<List<TranslationSegment>> translateBreakdown(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    _logger.info('TranslationService: Requesting breakdown');

    if (!_isOnline) {
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

      if (response.statusCode == 200) {
        final List segmentsJson = response.data['segments'] ?? [];
        return segmentsJson.map((s) => TranslationSegment.fromJson(s)).toList();
      }
      throw Exception('Breakdown failed');
    } catch (e, st) {
      _logger.error(
        'TranslationService: Error during translateBreakdown',
        e,
        st,
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
    _logger.info('TranslationService: Requesting contextual translation');

    if (!_isOnline) {
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
    } catch (e, st) {
      _logger.error(
        'TranslationService: Error during contextualTranslate',
        e,
        st,
      );
      if (_isOnline) rethrow;
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
          'Offline mode: Context-aware translation requires internet.',
      'isOffline': true,
    };
  }

  Stream<Map<String, dynamic>> streamContextualTranslation({
    required String selectedText,
    required String context,
    required String sourceLanguage,
    required String targetLanguage,
  }) async* {
    final cacheKey = '${selectedText}_${context}_$targetLanguage'.hashCode
        .toString();

    final cached = await _db.getCachedTranslation(cacheKey);
    if (cached != null) {
      yield {...cached, 'isFinal': true, 'source': 'cache'};
      return;
    }

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

  // Helper methods (originally in AIService)
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
    const names = {
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
    return names[code] ?? code.toUpperCase();
  }

  String _mapToMlKitCode(String language) {
    const map = {
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
    return map[language.toLowerCase()] ?? language.toLowerCase();
  }
}

final translationServiceProvider = Provider(
  (ref) => TranslationService(
    ref,
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
  ),
);
