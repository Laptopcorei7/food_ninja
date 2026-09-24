import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.greenDark,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.greenDark,
      secondary: AppColors.orange,
      error: AppColors.error,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: 'BentonSans',
      // Sizes from the designs (375-wide frames).
      textTheme: const TextTheme(
        // "Find Your Favorite Food" page titles
        headlineLarge: TextStyle(fontSize: 31, fontWeight: FontWeight.w700),
        // auth screen titles
        headlineMedium: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        // card titles, e.g. a dish name
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
        // button labels
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Text fields in 1.4-1.10: filled card, 15 radius, grey hint.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: c.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.green),
        ),
      ),
      extensions: [c],
    );
  }
}
