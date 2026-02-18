class UserProfile {
  final String id;
  final String email;
  final String? nativeLanguage;
  final String defaultTargetLanguage;
  final String? writingStyle;
  final String? writingPurpose; // New field
  final String? selfAssessedLevel; // New field
  final String subscriptionTier;
  final List<LanguageProfile> languageProfiles;

  UserProfile({
    required this.id,
    required this.email,
    this.nativeLanguage,
    required this.defaultTargetLanguage,
    this.writingStyle,
    this.writingPurpose,
    this.selfAssessedLevel,
    required this.subscriptionTier,
    this.languageProfiles = const [],
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
      languageProfiles: (json['languageProfiles'] as List? ?? [])
          .map((lp) => LanguageProfile.fromJson(lp))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nativeLanguage': nativeLanguage,
        'defaultTargetLanguage': defaultTargetLanguage,
        'writingStyle': writingStyle,
        'writingPurpose': writingPurpose,
        'selfAssessedLevel': selfAssessedLevel,
      };

  // Helper to clone object with updates
  UserProfile copyWith({
    String? nativeLanguage,
    String? defaultTargetLanguage,
    String? writingStyle,
    String? writingPurpose,
    String? selfAssessedLevel,
    List<LanguageProfile>? languageProfiles,
  }) {
    return UserProfile(
      id: id,
      email: email,
      subscriptionTier: subscriptionTier,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      defaultTargetLanguage: defaultTargetLanguage ?? this.defaultTargetLanguage,
      writingStyle: writingStyle ?? this.writingStyle,
      writingPurpose: writingPurpose ?? this.writingPurpose,
      selfAssessedLevel: selfAssessedLevel ?? this.selfAssessedLevel,
      languageProfiles: languageProfiles ?? this.languageProfiles,
    );
  }
}

class LanguageProfile {
  final String language;
  LanguageProfile({required this.language});
  factory LanguageProfile.fromJson(Map<String, dynamic> json) {
    return LanguageProfile(language: json['language'] ?? '');
  }
}
