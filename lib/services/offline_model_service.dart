import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../database/app_database.dart';
import '../services/logger_service.dart';

class OfflineModelService {
  final Ref _ref;
  final AppDatabase _db;
  late final LoggerService _logger;

  OfflineModelService(this._ref, this._db) {
    _logger = _ref.read(loggerProvider);
  }

  Future<ModelDownloadResult> downloadLanguageModel(String languageCode) async {
    final mlKitCode = _mapToMlKitCode(languageCode);
    final lang = _getTranslateLanguage(mlKitCode);
    final langName = _getLanguageName(languageCode);

    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final success = await modelManager.downloadModel(
        lang.bcpCode,
        isWifiRequired: false,
      );

      if (success) {
        await _db.saveDownloadedModel(languageCode, 'offline_translation');
        return ModelDownloadResult(
          success: true,
          languageName: langName,
          languageCode: languageCode,
        );
      }
      return ModelDownloadResult(
        success: false,
        languageName: langName,
        languageCode: languageCode,
        error: 'Download failed',
      );
    } catch (e) {
      return ModelDownloadResult(
        success: false,
        languageName: _getLanguageName(languageCode),
        languageCode: languageCode,
        error: 'Download failed',
      );
    }
  }

  Future<List<String>> getDownloadedModels() async {
    return await _db.getDownloadedModels();
  }

  Future<bool> isModelDownloaded(String languageCode) async {
    return await _db.isModelDownloaded(languageCode);
  }

  // Helpers (duplicated from TranslationService for independence)
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

final offlineModelServiceProvider = Provider(
  (ref) => OfflineModelService(ref, ref.watch(databaseProvider)),
);

// ModelDownloadResult class (move from AIService if needed, or define inline)
class ModelDownloadResult {
  final bool success;
  final String languageName;
  final String languageCode;
  final String? error;

  ModelDownloadResult({
    required this.success,
    required this.languageName,
    required this.languageCode,
    this.error,
  });
}
