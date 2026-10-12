import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFFD32F2F);
  static const primaryDark = Color(0xFFB71C1C);
  static const background = Color(0xFFF6F6F6);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF6F6F6F);
  static const border = Color(0xFFE6E6E6);
  static const success = Color(0xFF2E7D32);
  static const error = Color(0xFFD32F2F);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary, secondary: primaryDark, error: error),
      scaffoldBackgroundColor: background,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Color(0xFFFFE5E5),
        height: 68,
      ),
      dividerColor: border,
    );
  }
}
