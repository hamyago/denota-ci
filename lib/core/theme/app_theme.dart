// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Poppins',

    // ── AppBar ──────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.grey200,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),

    // ── Bottom Navigation ────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.grey400,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
      selectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),

    // ── Elevated Button ─────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Outlined Button ─────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Text Button ─────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Input fields ────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.grey100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppColors.grey400,
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppColors.grey500,
      ),
    ),

    // ── Card ────────────────────────────────────────
    cardTheme: CardTheme(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.grey200, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Chip ────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.grey100,
      selectedColor: AppColors.primaryBg,
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      side: BorderSide.none,
    ),

    // ── Divider ─────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.grey200,
      thickness: 1,
      space: 0,
    ),

    // ── Text ────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.ink, fontFamily: 'Poppins'),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink, fontFamily: 'Poppins'),
      displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink, fontFamily: 'Poppins'),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ink, fontFamily: 'Poppins'),
      headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink, fontFamily: 'Poppins'),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink, fontFamily: 'Poppins'),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink, fontFamily: 'Poppins'),
      titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink, fontFamily: 'Poppins'),
      titleSmall:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink, fontFamily: 'Poppins'),
      bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.grey700, fontFamily: 'Poppins'),
      bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.grey700, fontFamily: 'Poppins'),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.grey500, fontFamily: 'Poppins'),
      labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink, fontFamily: 'Poppins'),
      labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.grey600, fontFamily: 'Poppins'),
      labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.grey500, fontFamily: 'Poppins'),
    ),
  );
}
