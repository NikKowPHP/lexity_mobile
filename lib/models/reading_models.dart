class ReadingMaterial {
  final String id;
  final String title;
  final String content;
  final String level;
  final String? source;

  ReadingMaterial({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    this.source,
  });

  factory ReadingMaterial.fromJson(Map<String, dynamic> json) {
    return ReadingMaterial(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      level: json['level'] ?? 'INTERMEDIATE',
      source: json['source'],
    );
  }
}

class WritingTask {
  final String title;
  final String prompt;

  WritingTask({required this.title, required this.prompt});

  factory WritingTask.fromJson(Map<String, dynamic> json) {
    return WritingTask(
      title: json['title'] ?? '',
      prompt: json['prompt'] ?? '',
    );
  }
}

class ReadingTasksResponse {
  final WritingTask summary;
  final WritingTask comprehension;
  final WritingTask creative;

  ReadingTasksResponse({
    required this.summary,
    required this.comprehension,
    required this.creative,
  });

  factory ReadingTasksResponse.fromJson(Map<String, dynamic> json) {
    return ReadingTasksResponse(
      summary: WritingTask.fromJson(json['summary']),
      comprehension: WritingTask.fromJson(json['comprehension']),
      creative: WritingTask.fromJson(json['creative']),
    );
  }
}
