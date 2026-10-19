import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.orange,
      onPrimary: Colors.white,
      secondary: AppColors.yellow,
      error: AppColors.error,
      surface: c.background,
      onSurface: c.textPrimary,
    );

    final fieldShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: 'LeagueSpartan',
      // Sizes from the kit's 393-wide frames.
      textTheme: TextTheme(
        // the title in the yellow header
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        // "Welcome", "Shipping Address"
        titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        // field labels, list item titles
        titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: c.textBody,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: c.textBody,
        ),
        // button labels
        labelLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.header,
        foregroundColor: c.onHeader,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Cream fields with no outline; orange edge while typing.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.field,
        hintStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: c.hint,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: fieldShape,
        enabledBorder: fieldShape,
        focusedBorder: fieldShape.copyWith(
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
        errorBorder: fieldShape.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: fieldShape.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.orange : c.soft,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      extensions: [c],
    );
  }
}
