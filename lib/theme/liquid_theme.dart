// lib/theme/liquid_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiquidTheme {
  static const Color background = Color(0xFF000000);
  static const Color primaryAccent = Color(0xFF818CF8); // Indigo 400
  static const Color secondaryAccent = Color(0xFFF472B6); // Pink 400
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color cardGrey = Color(0xFF1A1A1A);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        backgroundColor: primaryAccent,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayMedium: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
        ),
        titleLarge: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        bodyMedium: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: cardGrey,
        onSurface: Colors.white,
      ),
      useMaterial3: true,
    );
  }
}
