class UserGoals {
  final int? weeklyActivities;
  final int? dailyStudyGoalInMinutes;
  final int? maxNewPerDay;
  final int? maxReviewsPerDay;

  UserGoals({
    this.weeklyActivities,
    this.dailyStudyGoalInMinutes,
    this.maxNewPerDay,
    this.maxReviewsPerDay,
  });

  factory UserGoals.fromJson(Map<String, dynamic> json) {
    // Check if 'srs' key exists, otherwise handle gracefully or check root if flattened
    final srs = json['srs'] as Map<String, dynamic>?;
    return UserGoals(
      weeklyActivities: json['weeklyActivities'],
      dailyStudyGoalInMinutes: json['dailyStudyGoalInMinutes'],
      maxNewPerDay: srs != null ? srs['maxNewPerDay'] : json['maxNewPerDay'],
      maxReviewsPerDay: srs != null
          ? srs['maxReviewsPerDay']
          : json['maxReviewsPerDay'],
    );
  }

  Map<String, dynamic> toJson() => {
    'weeklyActivities': weeklyActivities,
    'dailyStudyGoalInMinutes': dailyStudyGoalInMinutes,
    'srs': {'maxNewPerDay': maxNewPerDay, 'maxReviewsPerDay': maxReviewsPerDay},
  };
}

class LanguageProfile {
  final String language;
  LanguageProfile({required this.language});
  factory LanguageProfile.fromJson(Map<String, dynamic> json) {
    return LanguageProfile(language: json['language'] ?? '');
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? nativeLanguage;
  final String defaultTargetLanguage;
  final String? writingStyle;
  final String? writingPurpose;
  final String? selfAssessedLevel;
  final String subscriptionTier;
  final String? subscriptionStatus;
  final DateTime? subscriptionPeriodEnd;
  final List<LanguageProfile> languageProfiles;
  final UserGoals? goals;

  UserProfile({
    required this.id,
    required this.email,
    this.nativeLanguage,
    required this.defaultTargetLanguage,
    this.writingStyle,
    this.writingPurpose,
    this.selfAssessedLevel,
    required this.subscriptionTier,
    this.subscriptionStatus,
    this.subscriptionPeriodEnd,
    this.languageProfiles = const [],
    this.goals,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nativeLanguage: json['nativeLanguage'],
      defaultTargetLanguage: json['defaultTargetLanguage'] ?? 'spanish',
      writingStyle: json['writingStyle'],
      writingPurpose: json['writingPurpose'],
      selfAssessedLevel: json['selfAssessedLevel'],
      subscriptionTier: json['subscriptionTier'] ?? 'FREE',
      subscriptionStatus: json['subscriptionStatus'],
      subscriptionPeriodEnd: json['subscriptionPeriodEnd'] != null
          ? DateTime.parse(json['subscriptionPeriodEnd'])
          : null,
      languageProfiles: (json['languageProfiles'] as List? ?? [])
          .map((lp) => LanguageProfile.fromJson(lp))
          .toList(),
      goals: json['goals'] != null ? UserGoals.fromJson(json['goals']) : null,
    );
  }

  // Helper for optimistic updates
  UserProfile copyWith({
    String? nativeLanguage,
    String? defaultTargetLanguage,
    String? writingStyle,
    String? writingPurpose,
    String? selfAssessedLevel,
    List<LanguageProfile>? languageProfiles,
    UserGoals? goals,
  }) {
    return UserProfile(
      id: id,
      email: email,
      subscriptionTier: subscriptionTier,
      subscriptionStatus: subscriptionStatus,
      subscriptionPeriodEnd: subscriptionPeriodEnd,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      defaultTargetLanguage: defaultTargetLanguage ?? this.defaultTargetLanguage,
      writingStyle: writingStyle ?? this.writingStyle,
      writingPurpose: writingPurpose ?? this.writingPurpose,
      selfAssessedLevel: selfAssessedLevel ?? this.selfAssessedLevel,
      languageProfiles: languageProfiles ?? this.languageProfiles,
      goals: goals ?? this.goals,
    );
  }
}
