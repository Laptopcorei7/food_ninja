import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// The kit's thin orange "<" at the left of the header.
class CustomBackButton extends StatelessWidget {
  const CustomBackButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Back',
      // 48 dp tap area around a small glyph.
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.orange,
        size: 20,
      ),
    );
  }
}
