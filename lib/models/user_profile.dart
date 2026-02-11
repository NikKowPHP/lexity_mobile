class UserProfile {
  final String id;
  final String email;
  final String? nativeLanguage;
  final String defaultTargetLanguage;
  final String? writingStyle;
  final String subscriptionTier;

  UserProfile({
    required this.id,
    required this.email,
    this.nativeLanguage,
    required this.defaultTargetLanguage,
    this.writingStyle,
    required this.subscriptionTier,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nativeLanguage: json['nativeLanguage'],
      defaultTargetLanguage: json['defaultTargetLanguage'] ?? 'Spanish',
      writingStyle: json['writingStyle'],
      subscriptionTier: json['subscriptionTier'] ?? 'FREE',
    );
  }

  Map<String, dynamic> toJson() => {
    'nativeLanguage': nativeLanguage,
    'defaultTargetLanguage': defaultTargetLanguage,
    'writingStyle': writingStyle,
  };
}
