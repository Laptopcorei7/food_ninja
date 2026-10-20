import 'package:flutter/material.dart';

/// YumQuick kit colours, measured from `new_designs/` (light). Dark values are
/// derived from them: the kit has no dark mode. Read them with
/// `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.header,
    required this.onHeader,
    required this.background,
    required this.surface,
    required this.field,
    required this.soft,
    required this.divider,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.hint,
    required this.accentText,
    required this.shadow,
  });

  // Brand colours, the same in both modes.
  static const yellow = Color(0xFFF5CB58);
  static const orange = Color(0xFFE95322);
  static const cream = Color(0xFFF3E9B5);
  static const peach = Color(0xFFFFDECF);
  static const brown = Color(0xFF391713);
  static const error = Color(0xFFD32F2F);

  static const light = AppColors(
    header: yellow,
    // The kit has white titles on the yellow (1.5:1); dark brown reads.
    onHeader: brown,
    background: Color(0xFFF5F5F5),
    surface: Colors.white,
    field: cream,
    soft: peach,
    divider: peach,
    textPrimary: brown,
    textBody: Color(0xFF252525),
    textSecondary: Color(0xFF6E5A55),
    hint: Color(0x80391713),
    // The kit's orange is 3.4:1 on the sheet; this is 5.3:1 for small text.
    accentText: Color(0xFFB83A12),
    shadow: Color(0x14391713),
  );

  static const dark = AppColors(
    header: Color(0xFF2B2218),
    onHeader: yellow,
    background: Color(0xFF1A1512),
    surface: Color(0xFF241D18),
    field: Color(0xFF352C20),
    soft: Color(0xFF3D2419),
    divider: Color(0xFF33281F),
    textPrimary: Color(0xFFF5EDE6),
    textBody: Color(0xFFDCD2CA),
    textSecondary: Color(0xFFA89B92),
    hint: Color(0xFF8C7F75),
    accentText: Color(0xFFFF8A5C),
    shadow: Colors.transparent,
  );

  /// The yellow band at the top of most screens.
  final Color header;

  /// Titles and icons on [header].
  final Color onHeader;

  /// The rounded sheet under the header, and plain screens.
  final Color background;

  /// Cards and the search field.
  final Color surface;

  /// Text fields.
  final Color field;

  /// Secondary buttons, unselected chips, off switches.
  final Color soft;
  final Color divider;

  /// Headings and field text.
  final Color textPrimary;

  /// Paragraphs.
  final Color textBody;
  final Color textSecondary;
  final Color hint;

  /// Small orange text (links, prices) on light grounds.
  final Color accentText;
  final Color shadow;

  @override
  AppColors copyWith({
    Color? header,
    Color? onHeader,
    Color? background,
    Color? surface,
    Color? field,
    Color? soft,
    Color? divider,
    Color? textPrimary,
    Color? textBody,
    Color? textSecondary,
    Color? hint,
    Color? accentText,
    Color? shadow,
  }) {
    return AppColors(
      header: header ?? this.header,
      onHeader: onHeader ?? this.onHeader,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      field: field ?? this.field,
      soft: soft ?? this.soft,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textBody: textBody ?? this.textBody,
      textSecondary: textSecondary ?? this.textSecondary,
      hint: hint ?? this.hint,
      accentText: accentText ?? this.accentText,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      header: mix(header, other.header),
      onHeader: mix(onHeader, other.onHeader),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      field: mix(field, other.field),
      soft: mix(soft, other.soft),
      divider: mix(divider, other.divider),
      textPrimary: mix(textPrimary, other.textPrimary),
      textBody: mix(textBody, other.textBody),
      textSecondary: mix(textSecondary, other.textSecondary),
      hint: mix(hint, other.hint),
      accentText: mix(accentText, other.accentText),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
