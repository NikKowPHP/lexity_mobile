class VocabularyItem {
  final String word;
  final String status;

  VocabularyItem({required this.word, required this.status});

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      status: json['status'] as String,
    );
  }
}