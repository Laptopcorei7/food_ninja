import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: value
              ? const LinearGradient(
                  colors: [
                    Color(0xFF53E88B),
                    Color(0xFF15BE77),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: value ? null : const Color(0xFFE0E0E0), // light grey
        ),
        child: value
            ? const Center(
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}
