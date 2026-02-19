class LearningModule {
  final String id;
  final String title;
  final String status; // PENDING, IN_PROGRESS, COMPLETED
  final String targetConceptTag;
  final String microLesson;
  final Map<String, dynamic> activities;
  final DateTime? completedAt;

  LearningModule({
    required this.id,
    required this.title,
    required this.status,
    required this.targetConceptTag,
    required this.microLesson,
    required this.activities,
    this.completedAt,
  });

  factory LearningModule.fromJson(Map<String, dynamic> json) {
    return LearningModule(
      id: json['id'],
      title: json['title'] ?? '',
      status: json['status'] ?? 'PENDING',
      targetConceptTag: json['targetConceptTag'] ?? '',
      microLesson: json['microLesson'] ?? '',
      activities: json['activities'] ?? {},
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }
}
