import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.darkSurface,
          onPrimary: AppColors.white,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: AppTypography.h3,
        ),
        textTheme: _buildTextTheme(light: false),
        inputDecorationTheme: _buildInputTheme(light: false),
        elevatedButtonTheme: _buildButtonTheme(),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        pageTransitionsTheme: _pageTransitions,
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.lightSurface,
          onPrimary: AppColors.white,
          onSurface: AppColors.textDark,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textDark),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        textTheme: _buildTextTheme(light: true),
        inputDecorationTheme: _buildInputTheme(light: true),
        elevatedButtonTheme: _buildButtonTheme(),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
        pageTransitionsTheme: _pageTransitions,
      );

  static TextTheme _buildTextTheme({required bool light}) {
    final bodyColor = light ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final headingColor = light ? AppColors.textDark : AppColors.textPrimary;
    return TextTheme(
      displayLarge: AppTypography.display.copyWith(color: headingColor),
      displayMedium: AppTypography.displayMedium.copyWith(color: headingColor),
      headlineLarge: AppTypography.h1.copyWith(color: headingColor),
      headlineMedium: AppTypography.h2.copyWith(color: headingColor),
      headlineSmall: AppTypography.h3.copyWith(color: headingColor),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: bodyColor),
      bodyMedium: AppTypography.body.copyWith(color: bodyColor),
      bodySmall: AppTypography.bodySmall,
      labelLarge: AppTypography.labelLarge.copyWith(color: headingColor),
      labelMedium: AppTypography.label.copyWith(color: headingColor),
      labelSmall: AppTypography.labelSmall,
    );
  }

  static InputDecorationTheme _buildInputTheme({required bool light}) {
    final bg = light ? AppColors.lightSurface : AppColors.darkSurface;
    final border = light ? AppColors.lightBorder : AppColors.darkBorder;
    return InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: AppTypography.body,
      labelStyle: AppTypography.body,
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  static ElevatedButtonThemeData _buildButtonTheme() =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          elevation: 0,
          textStyle: AppTypography.labelLarge,
        ),
      );

  static final PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: const ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: const ZoomPageTransitionsBuilder(),
    },
  );
}
