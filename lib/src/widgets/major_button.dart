import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

class MajorButton extends StatelessWidget {
  const MajorButton({
    required this.horizontal,
    required this.vertical,
    required this.textonButton,
    this.onPress,
    super.key,
  });
  final double horizontal;
  final double vertical;
  final String textonButton;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: Colors.white);
    // BentonSans reserves 0.2 em below the baseline and nothing above the
    // capitals, so a label without descenders looks high. Moving it down by
    // 0.1 em centres the letters in the button.
    final nudge = (style?.fontSize ?? 16) * 0.1;
    return InkWell(
      onTap: onPress,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.green, AppColors.greenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          vertical + nudge,
          horizontal,
          vertical - nudge,
        ),
        child: Text(textonButton, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}
