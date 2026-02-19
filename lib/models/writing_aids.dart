class WritingAids {
  final String sentenceStarter;
  final List<String> suggestedVocab;

  WritingAids({required this.sentenceStarter, required this.suggestedVocab});

  factory WritingAids.fromJson(Map<String, dynamic> json) {
    return WritingAids(
      sentenceStarter: json['sentenceStarter'] ?? '',
      suggestedVocab: (json['suggestedVocab'] as List?)
          ?.map((item) => item as String)
          .toList() ?? [],
    );
  }
}
