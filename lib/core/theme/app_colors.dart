import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFFFF4500); // Enerji Turuncusu
  static const Color primaryLight  = Color(0xFFFF6A33); // Açık turuncu
  static const Color primaryDark   = Color(0xFFCC3700); // Koyu turuncu
  static const Color secondary     = Color(0xFFFF8C00); // Gradient ikinci renk

  // Gradient tanımları
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: [Color(0xFF1A0A00), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF22C55E);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color danger   = Color(0xFFEF4444);
  static const Color info     = Color(0xFF0066FF);

  // ── Light Theme ────────────────────────────────────────────────────────
  static const Color lightBg        = Color(0xFFF5F5F7);
  static const Color lightSurface   = Color(0xFFFFFFFF);
  static const Color lightSurface2  = Color(0xFFF0F0F2);
  static const Color lightBorder    = Color(0xFFE5E5EA);
  static const Color lightText      = Color(0xFF1C1C1E);
  static const Color lightTextSub   = Color(0xFF6C6C70);

  // ── Dark Theme ─────────────────────────────────────────────────────────
  static const Color darkBg        = Color(0xFF0A0A0F);
  static const Color darkSurface   = Color(0xFF14141C);
  static const Color darkSurface2  = Color(0xFF1C1C26);
  static const Color darkBorder    = Color(0xFF2C2C38);
  static const Color darkText      = Color(0xFFF5F5F7);
  static const Color darkTextSub   = Color(0xFF9898A8);
}
