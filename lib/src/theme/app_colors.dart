import 'package:flutter/material.dart';

/// Colors measured from `UI design/`: light values from the 1.x screens,
/// dark values from the 2.x screens. Read them with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.searchField,
    required this.inactive,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.hint,
    required this.shadow,
    required this.backButton,
  });

  // Brand colors, the same in both modes.
  static const green = Color(0xFF53E88B);
  static const greenDark = Color(0xFF15BE77);
  static const orange = Color(0xFFDA6317);
  static const error = Color(0xFFE53935);
  static const brandGradient = LinearGradient(colors: [green, greenDark]);

  static const light = AppColors(
    background: Colors.white,
    surface: Colors.white,
    searchField: Color(0xFFFEF6EE),
    inactive: Color(0xFFF6F6F6),
    border: Color(0xFFF4F4F4),
    textPrimary: Color(0xFF09051C),
    // #3B3B3B at 30%, the subtitle grey on white cards.
    textSecondary: Color(0x4D3B3B3B),
    // Orange at 40%, the hint text in the search field.
    hint: Color(0x66DA6317),
    // Blue-tinted shadow at 7%, visible under the white cards.
    shadow: Color(0x125A6CEA),
    backButton: Color(0xFFF9E8D8),
  );

  static const dark = AppColors(
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF252525),
    searchField: Color(0xFF252525),
    inactive: Color(0xFF252525),
    border: Color(0xFF252525),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF666666),
    hint: Color(0xFF7C7C7C),
    shadow: Colors.transparent,
    // Orange at 20%, the brown square behind the back arrow in 2.6.
    backButton: Color(0x33DA6317),
  );

  final Color background;
  final Color surface;
  final Color searchField;
  final Color inactive;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color hint;
  final Color shadow;
  final Color backButton;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? searchField,
    Color? inactive,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? hint,
    Color? shadow,
    Color? backButton,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      searchField: searchField ?? this.searchField,
      inactive: inactive ?? this.inactive,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      hint: hint ?? this.hint,
      shadow: shadow ?? this.shadow,
      backButton: backButton ?? this.backButton,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      searchField: Color.lerp(searchField, other.searchField, t)!,
      inactive: Color.lerp(inactive, other.inactive, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      backButton: Color.lerp(backButton, other.backButton, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
