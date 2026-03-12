import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static String get baseUrl {
    // Determine if we are in production mode. 
    // Uses kReleaseMode (true for release builds) or a custom --dart-define=IS_PROD=true flag.
    const bool isProd = bool.fromEnvironment('IS_PROD', defaultValue: kReleaseMode);

    if (isProd) {
      return 'https://www.lexity.app';
    }

    // Development fallbacks
    if (kIsWeb) {
      return 'http://localhost:3555';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 is the alias for the host loopback interface in the Android emulator
      return 'http://10.0.2.2:3555';
    }
    return 'http://localhost:3555';
  }

  static const List<Map<String, String>> supportedLanguages = [
    {'name': "English", 'value': "english"},
    {'name': "Spanish", 'value': "spanish"},
    {'name': "French", 'value': "french"},
    {'name': "German", 'value': "german"},
    {'name': "Polish", 'value': "polish"},
    {'name': "Italian", 'value': "italian"},
    {'name': "Portuguese", 'value': "portuguese"},
    {'name': "Russian", 'value': "russian"},
    {'name': "Japanese", 'value': "japanese"},
    {'name': "Korean", 'value': "korean"},
    {'name': "Mandarin Chinese", 'value': "mandarin"},
    {'name': "Arabic", 'value': "arabic"},
    {'name': "Hindi", 'value': "hindi"},
  ];

  static const List<String> writingStyles = ["Casual", "Formal", "Academic"];
  static const List<String> writingPurposes = ["Personal", "Professional", "Creative"];
  static const List<String> proficiencyLevels = ["Beginner", "Intermediate", "Advanced"];
  
  static String getLanguageName(String value) {
    final lang = supportedLanguages.firstWhere(
      (element) => element['value'] == value, 
      orElse: () => {'name': value, 'value': value}
    );
    return lang['name']!;
  }
}
