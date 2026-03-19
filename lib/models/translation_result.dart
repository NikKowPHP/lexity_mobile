class TranslationSegment {
  final String source;
  final String translation;
  final String explanation;

  TranslationSegment({
    required this.source,
    required this.translation,
    required this.explanation,
  });

  factory TranslationSegment.fromJson(Map<String, dynamic> json) {
    return TranslationSegment(
      source: json['source'] ?? '',
      translation: json['translation'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}

class TranslationUnavailable {
  final String message;
  final List<String> missingLanguages;
  final List<String> missingLanguageCodes;

  TranslationUnavailable({
    required this.message,
    required this.missingLanguages,
    required this.missingLanguageCodes,
  });

  @override
  String toString() => message;

  bool get needsDownload => missingLanguageCodes.isNotEmpty;
}

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
