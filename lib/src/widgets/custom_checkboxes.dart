import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

class CustomCheckbox extends StatelessWidget {
  const CustomCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: value ? AppColors.brandGradient : null,
            color: value ? null : context.colors.textSecondary,
          ),
          child: value
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
