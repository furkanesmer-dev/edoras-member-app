import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ✅ Mor yerine canlı/premium mavi (istersen teal'e de çeviririz)
  static const Color _seed = Color(0xFF1E88E5); // canlı mavi

  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,

      // ✅ Daha beyaz, daha temiz
      scaffoldBackgroundColor: const Color(0xFFFAFAFD),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),

      // ✅ Kartlar beyaz, border çok hafif
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: cs.outlineVariant.withOpacity(0.22),
            width: 1,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest.withOpacity(0.65),
        selectedColor: cs.primary.withOpacity(0.14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.30)),
        labelStyle: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        // ✅ Beyaz tonlu navbar
        backgroundColor: Colors.white.withOpacity(0.90),
        indicatorColor: cs.primary.withOpacity(0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          );
        }),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(0.30),
        thickness: 1,
        space: 1,
      ),

      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.1),
        bodyLarge: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFF0F1115),
    );
  }
}