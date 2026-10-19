import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';

/// The heart mark over the two-tone YUMQUICK wordmark (launch screens 0-A,
/// 0-B). On yellow: orange mark, "YUM" orange, "QUICK" white. On orange:
/// yellow mark, "YUM" yellow, "QUICK" white.
class YumQuickLogo extends StatelessWidget {
  const YumQuickLogo({this.onOrange = false, this.size = 160, super.key});

  /// True on the orange welcome screen.
  final bool onOrange;

  /// Width of the heart mark; the wordmark scales with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = onOrange ? AppColors.yellow : AppColors.orange;
    final style = TextStyle(
      fontFamily: 'LeagueSpartan',
      fontSize: size * 0.3,
      fontWeight: FontWeight.w800,
      height: 1,
    );
    return Semantics(
      label: 'YumQuick',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageIcon(AppIcons.logoMark, size: size, color: accent),
          SizedBox(height: size * 0.12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'YUM', style: style.copyWith(color: accent)),
                TextSpan(
                  text: 'QUICK',
                  style: style.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
