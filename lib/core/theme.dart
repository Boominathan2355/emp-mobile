import 'package:flutter/material.dart';

/// Dark theme matching the screenshots: near-black background, blurple accent,
/// elevated cards a shade lighter than the page.
class AppTheme {
  static const Color accent = Color(0xFF4C8DFF); // Check In blue
  static const Color bg = Color(0xFF0E0E10);
  static const Color card = Color(0xFF2A2B2F);
  static const Color cardAlt = Color(0xFF1C1D21);
  static const Color textPrimary = Color(0xFFF4F5F7);
  static const Color textMuted = Color(0xFF9BA0A8);
  static const Color success = Color(0xFF3BB273);
  static const Color danger = Color(0xFFE5484D); // check-out / failure red
  static const Color warning = Color(0xFFF5A524); // location-off countdown

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        surface: card,
        secondary: accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardColor: card,
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}
