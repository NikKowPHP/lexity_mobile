class JournalEntry {
  final String id;
  final String content;
  final String title;
  final DateTime createdAt;
  final String? audioUrl;
  final Analysis? analysis;
  final bool isPending;

  JournalEntry({
    required this.id,
    required this.content,
    required this.title,
    required this.createdAt,
    this.audioUrl,
    this.analysis,
    this.isPending = false,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      content: json['content'] ?? '',
      title: json['topic']?['title'] ?? 'Free Write',
      createdAt: DateTime.parse(json['createdAt']),
      audioUrl: json['audioUrl'],
      analysis: json['analysis'] != null ? Analysis.fromJson(json['analysis']) : null,
    );
  }
}

class Analysis {
  final String id;
  final int grammarScore;
  final int phrasingScore;
  final int vocabScore;
  final String feedback;
  final List<Mistake> mistakes;

  Analysis({
    required this.id,
    required this.grammarScore,
    required this.phrasingScore,
    required this.vocabScore,
    required this.feedback,
    required this.mistakes,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) {
    // Handle rawAiResponse structure if present, or flat structure
    String feedbackText = json['feedbackJson'] ?? '';
    // In some API responses, feedback might be nested or encrypted string on server, 
    // but client receives decrypted. Assuming standard JSON here.
    
    return Analysis(
      id: json['id'],
      grammarScore: json['grammarScore'] ?? 0,
      phrasingScore: json['phrasingScore'] ?? 0,
      vocabScore: json['vocabScore'] ?? 0,
      feedback: feedbackText,
      mistakes: (json['mistakes'] as List? ?? [])
          .map((m) => Mistake.fromJson(m))
          .toList(),
    );
  }
}

class Mistake {
  final String id;
  final String original;
  final String corrected;
  final String explanation;
  final String type;

  Mistake({
    required this.id,
    required this.original,
    required this.corrected,
    required this.explanation,
    required this.type,
  });

  factory Mistake.fromJson(Map<String, dynamic> json) {
    return Mistake(
      id: json['id'],
      original: json['originalText'] ?? '',
      corrected: json['correctedText'] ?? '',
      explanation: json['explanation'] ?? '',
      type: json['type'] ?? 'grammar',
    );
  }
}
