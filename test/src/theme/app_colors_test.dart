import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] painted over [bg], so a translucent hint is judged as it is seen.
double contrastOver(Color fg, Color bg) =>
    contrast(Color.alphaBlend(fg, bg), bg);

void main() {
  // Guards future colour edits: text must stay readable in both modes.
  for (final (mode, c) in [
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    group('$mode mode', () {
      test('header titles: 4.5:1 on the header', () {
        expect(contrast(c.onHeader, c.header), greaterThanOrEqualTo(4.5));
      });

      test('headings and paragraphs: 4.5:1 on the sheet and in fields', () {
        for (final ground in [c.background, c.surface, c.field]) {
          expect(contrast(c.textPrimary, ground), greaterThanOrEqualTo(4.5));
          expect(contrast(c.textBody, ground), greaterThanOrEqualTo(4.5));
        }
      });

      test('secondary text: 4.5:1 on the sheet', () {
        expect(
          contrast(c.textSecondary, c.background),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('small orange text: 4.5:1 on the sheet and on soft buttons', () {
        expect(contrast(c.accentText, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.accentText, c.soft), greaterThanOrEqualTo(4.5));
      });

      test('field hints: 3:1, the placeholder minimum', () {
        expect(contrastOver(c.hint, c.field), greaterThanOrEqualTo(3));
      });
    });
  }

  test('white button labels on orange: 3:1 (large or bold text)', () {
    expect(contrast(Colors.white, AppColors.orange), greaterThanOrEqualTo(3));
  });

  test('lerp ends on the target theme', () {
    final mid = AppColors.light.lerp(AppColors.dark, 1);
    expect(mid.background, AppColors.dark.background);
    expect(mid.header, AppColors.dark.header);
  });
}
