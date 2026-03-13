import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static String get baseUrl {
    // Allow override via --dart-define=API_URL=https://api.example.com
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Determine if we are in production mode.
    const bool isProd = bool.fromEnvironment('IS_PROD', defaultValue: kReleaseMode);

    if (isProd) {
      return 'https://www.lexity.app';
    }

    // Web handles loopback differently; 127.0.0.1 is often safer than 'localhost'
    if (kIsWeb) {
      return 'http://127.0.0.1:3555';
    }

    // Use 10.0.2.2 only for Android physical/emulator when not on Web
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3555';
      }
    } catch (_) {
      // Fallback if Platform access fails
    }

    return 'http://127.0.0.1:3555';
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
