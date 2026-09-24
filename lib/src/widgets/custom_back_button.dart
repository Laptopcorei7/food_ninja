import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: context.colors.backButton,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.chevron_left,
            color: AppColors.orange,
            size: 28,
          ),
        ),
      ),
    );
  }
}
