import 'package:flutter/material.dart';
import 'package:lexity_mobile/utils/constants.dart';

class OnboardingData {
  final String nativeLanguage;
  final String targetLanguage;
  final String writingStyle;
  final String writingPurpose;
  final String selfAssessedLevel;

  const OnboardingData({
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.writingStyle,
    required this.writingPurpose,
    required this.selfAssessedLevel,
  });

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      nativeLanguage: json['nativeLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      writingStyle: json['writingStyle'] as String,
      writingPurpose: json['writingPurpose'] as String,
      selfAssessedLevel: json['selfAssessedLevel'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nativeLanguage': nativeLanguage,
      'targetLanguage': targetLanguage,
      'writingStyle': writingStyle,
      'writingPurpose': writingPurpose,
      'selfAssessedLevel': selfAssessedLevel,
    };
  }
}

enum PasswordStrength { weak, fair, good, strong }

extension PasswordStrengthExtension on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.good:
        return Colors.lightGreen;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  int get score {
    switch (this) {
      case PasswordStrength.weak:
        return 1;
      case PasswordStrength.fair:
        return 2;
      case PasswordStrength.good:
        return 3;
      case PasswordStrength.strong:
        return 4;
    }
  }
}

class PasswordValidation {
  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp _numberRegex = RegExp(r'[0-9]');
  static final RegExp _specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  static PasswordStrength validate(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    int score = 0;
    if (password.length >= 8) score++;
    if (_uppercaseRegex.hasMatch(password)) score++;
    if (_lowercaseRegex.hasMatch(password)) score++;
    if (_numberRegex.hasMatch(password)) score++;
    if (_specialCharRegex.hasMatch(password)) score++;

    switch (score) {
      case 0:
      case 1:
        return PasswordStrength.weak;
      case 2:
        return PasswordStrength.fair;
      case 3:
        return PasswordStrength.good;
      case 4:
      case 5:
        return PasswordStrength.strong;
      default:
        return PasswordStrength.weak;
    }
  }
}
