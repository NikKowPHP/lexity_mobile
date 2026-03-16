// lib/theme/liquid_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiquidTheme {
  static const Color backgroundDark = Color(0xFF000000);
  static const Color backgroundLight = Color(0xFFF9F9F9);

  static const Color primaryAccent = Color(0xFF818CF8);
  static const Color secondaryAccent = Color(0xFFF472B6);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color cardGrey = Color(0xFF1A1A1A);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? backgroundDark : backgroundLight,
      primaryColor: primaryAccent,
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        backgroundColor: primaryAccent,
      ),
      textTheme:
          GoogleFonts.interTextTheme(
            isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
          ).copyWith(
            displayMedium: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
            titleLarge: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
            bodyMedium: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 16,
              height: 1.5,
            ),
          ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: brightness,
        surface: isDark ? cardGrey : Colors.white,
      ),
      useMaterial3: true,
    );
  }
}
