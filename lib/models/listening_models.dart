import 'reading_models.dart'; // Reusing WritingTask from reading models

class ListeningExercise {
  final String id;
  final String title;
  final String videoId;
  final String transcript;
  final String level;
  final String? source;

  ListeningExercise({
    required this.id,
    required this.title,
    required this.videoId,
    required this.transcript,
    required this.level,
    this.source,
  });

  factory ListeningExercise.fromJson(Map<String, dynamic> json) {
    return ListeningExercise(
      id: json['id'],
      title: json['title'] ?? '',
      videoId: json['videoId'] ?? '',
      transcript: json['transcript'] ?? '',
      level: json['level'] ?? 'INTERMEDIATE',
      source: json['source'],
    );
  }
}

class ListeningTasksResponse {
  final WritingTask summary;
  final WritingTask comprehension;

  ListeningTasksResponse({
    required this.summary,
    required this.comprehension,
  });

  factory ListeningTasksResponse.fromJson(Map<String, dynamic> json) {
    return ListeningTasksResponse(
      summary: WritingTask.fromJson(json['summary']),
      comprehension: WritingTask.fromJson(json['comprehension']),
    );
  }
}
