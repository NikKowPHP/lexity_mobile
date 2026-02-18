class UserProfile {
  final String id;
  final String email;
  final String? nativeLanguage;
  final String defaultTargetLanguage;
  final String? writingStyle;
  final String subscriptionTier;
  final List<LanguageProfile> languageProfiles;

  UserProfile({
    required this.id,
    required this.email,
    this.nativeLanguage,
    required this.defaultTargetLanguage,
    this.writingStyle,
    required this.subscriptionTier,
    this.languageProfiles = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nativeLanguage: json['nativeLanguage'],
      // Ensure we capitalize or normalize if the backend is inconsistent
      defaultTargetLanguage: json['defaultTargetLanguage'] ?? 'Spanish',
      writingStyle: json['writingStyle'],
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
  };
}

class LanguageProfile {
  final String language;
  LanguageProfile({required this.language});
  factory LanguageProfile.fromJson(Map<String, dynamic> json) {
    return LanguageProfile(language: json['language'] ?? '');
  }
}
