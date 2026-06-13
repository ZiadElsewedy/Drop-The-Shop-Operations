import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF5B5FEF);
  static const Color primaryLight = Color(0xFF7B7FF5);
  static const Color primaryDark = Color(0xFF3D40C4);

  // Gradient
  static const Color gradientStart = Color(0xFF5B5FEF);
  static const Color gradientEnd = Color(0xFF9B59F5);

  // Dark theme backgrounds
  static const Color darkBg = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF171A21);
  static const Color darkSurfaceElevated = Color(0xFF1E2130);
  static const Color darkBorder = Color(0xFF252836);

  // Light theme backgrounds
  static const Color lightBg = Color(0xFFF8F9FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF0F2FF);
  static const Color lightBorder = Color(0xFFE4E6F0);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B8FA8);
  static const Color textTertiary = Color(0xFF555870);
  static const Color textDark = Color(0xFF0F1115);
  static const Color textDarkSecondary = Color(0xFF4A4D60);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFF0D2E1A);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFF2E0D0D);
  static const Color warning = Color(0xFFF59E0B);

  // Utility
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0x205B5FEF), Color(0x109B59F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
