import 'package:flutter/material.dart';

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
    return InkWell(
      onTap: onPress,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF53E88B),
              Color(0xFF15BE77),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: vertical,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                textonButton,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'BentonSansBold',
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
