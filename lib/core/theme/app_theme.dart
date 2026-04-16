import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFFFF4500);

  // ── LIGHT ─────────────────────────────────────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBg,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.lightText,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: AppColors.lightText,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface2,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        side: const BorderSide(color: AppColors.lightBorder),
        labelStyle: const TextStyle(
          color: AppColors.lightText,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: AppColors.lightTextSub,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.lightTextSub,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, color: AppColors.lightText),
        displayMedium: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.8, color: AppColors.lightText),
        displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.lightText),
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.lightText),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.lightText),
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2, color: AppColors.lightText),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.lightText),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.1, color: AppColors.lightText),
        titleSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0, color: AppColors.lightText),
        bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.lightText),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: AppColors.lightText),
        bodySmall: TextStyle(fontWeight: FontWeight.w500, color: AppColors.lightTextSub),
        labelLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1, color: AppColors.lightText),
        labelMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.lightText),
        labelSmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.lightTextSub),
      ),
    );
  }

  // ── DARK ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.darkBg,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.darkText,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: AppColors.darkText,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface2,
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.20),
        side: const BorderSide(color: AppColors.darkBorder),
        labelStyle: const TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: AppColors.darkTextSub,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.darkTextSub,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, color: AppColors.darkText),
        displayMedium: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.8, color: AppColors.darkText),
        displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.darkText),
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.darkText),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.darkText),
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2, color: AppColors.darkText),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.darkText),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.1, color: AppColors.darkText),
        titleSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0, color: AppColors.darkText),
        bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: AppColors.darkText),
        bodySmall: TextStyle(fontWeight: FontWeight.w500, color: AppColors.darkTextSub),
        labelLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1, color: AppColors.darkText),
        labelMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.darkText),
        labelSmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.darkTextSub),
      ),
    );
  }
}
