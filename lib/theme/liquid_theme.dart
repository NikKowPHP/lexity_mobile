// lib/theme/liquid_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiquidTheme {
  static const Color background = Color(0xFF050505);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color primaryAccent = Color(0xFF6366F1); // Electric Indigo
  static const Color secondaryAccent = Color(0xFFEC4899); // Neon Pink

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: Colors.transparent, // Important for glass
      ),
      useMaterial3: true,
    );
  }
}
