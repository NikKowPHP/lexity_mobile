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
