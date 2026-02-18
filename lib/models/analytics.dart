class AnalyticsData {
  final int totalEntries;
  final double averageScore;
  final String weakestSkill;
  final List<TimePoint> proficiencyOverTime;
  final SubskillScores subskillScores;
  final DueCounts dueCounts;
  final int studyTimeToday;
  final List<TimePoint> predictedProficiencyOverTime;

  AnalyticsData({
    required this.totalEntries,
    required this.averageScore,
    required this.weakestSkill,
    required this.proficiencyOverTime,
    required this.subskillScores,
    required this.dueCounts,
    required this.studyTimeToday,
    required this.predictedProficiencyOverTime,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      totalEntries: json['totalEntries'] ?? 0,
      averageScore: (json['averageScore'] ?? 0).toDouble(),
      weakestSkill: json['weakestSkill'] ?? 'N/A',
      proficiencyOverTime: (json['proficiencyOverTime'] as List? ?? [])
          .map((e) => TimePoint.fromJson(e))
          .toList(),
      subskillScores: SubskillScores.fromJson(json['subskillScores'] ?? {}),
      dueCounts: DueCounts.fromJson(json['dueCounts'] ?? {}),
      studyTimeToday: json['studyTimeToday'] ?? 0,
      predictedProficiencyOverTime:
          (json['predictedProficiencyOverTime'] as List? ?? [])
              .map((e) => TimePoint.fromJson(e))
              .toList(),
    );
  }
}

class TimePoint {
  final String date;
  final double score;

  TimePoint({required this.date, required this.score});

  factory TimePoint.fromJson(Map<String, dynamic> json) {
    return TimePoint(
      date: json['date'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
    );
  }
}

class SubskillScores {
  final double grammar;
  final double phrasing;
  final double vocabulary;

  SubskillScores({
    required this.grammar,
    required this.phrasing,
    required this.vocabulary,
  });

  factory SubskillScores.fromJson(Map<String, dynamic> json) {
    return SubskillScores(
      grammar: (json['grammar'] ?? 0).toDouble(),
      phrasing: (json['phrasing'] ?? 0).toDouble(),
      vocabulary: (json['vocabulary'] ?? 0).toDouble(),
    );
  }
}

class DueCounts {
  final int today;
  final int tomorrow;
  final int week;

  DueCounts({required this.today, required this.tomorrow, required this.week});

  factory DueCounts.fromJson(Map<String, dynamic> json) {
    return DueCounts(
      today: json['today'] ?? 0,
      tomorrow: json['tomorrow'] ?? 0,
      week: json['week'] ?? 0,
    );
  }
}

class GoalProgress {
  final int completedActivities;
  final int goal;
  final GoalBreakdown breakdown;

  GoalProgress({
    required this.completedActivities,
    required this.goal,
    required this.breakdown,
  });

  factory GoalProgress.fromJson(Map<String, dynamic> json) {
    return GoalProgress(
      completedActivities: json['completedActivities'] ?? 0,
      goal: json['goal'] ?? 0,
      breakdown: GoalBreakdown.fromJson(json['breakdown'] ?? {}),
    );
  }
}

class GoalBreakdown {
  final int modules;
  final int journals;
  final int sessions;

  GoalBreakdown({required this.modules, required this.journals, required this.sessions});

  factory GoalBreakdown.fromJson(Map<String, dynamic> json) {
    return GoalBreakdown(
      modules: json['modules'] ?? 0,
      journals: json['journals'] ?? 0,
      sessions: json['sessions'] ?? 0,
    );
  }
}

class ActivityHeatmapPoint {
  final String date;
  final int totalSeconds;

  ActivityHeatmapPoint({required this.date, required this.totalSeconds});

  factory ActivityHeatmapPoint.fromJson(Map<String, dynamic> json) {
    return ActivityHeatmapPoint(
      date: json['date'],
      totalSeconds: json['total_seconds'] ?? 0,
    );
  }
}

class PracticeConcept {
  final String mistakeId;
  final double averageScore;
  final int attempts;
  final String explanation;
  final String originalText;
  final String correctedText;

  PracticeConcept({
    required this.mistakeId,
    required this.averageScore,
    required this.attempts,
    required this.explanation,
    required this.originalText,
    required this.correctedText,
  });

  factory PracticeConcept.fromJson(Map<String, dynamic> json) {
    return PracticeConcept(
      mistakeId: json['mistakeId'] ?? '',
      averageScore: (json['averageScore'] ?? 0).toDouble(),
      attempts: json['attempts'] ?? 0,
      explanation: json['explanation'] ?? '',
      originalText: json['originalText'] ?? '',
      correctedText: json['correctedText'] ?? '',
    );
  }
}
