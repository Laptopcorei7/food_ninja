import 'package:flutter/material.dart';

class MajorButton extends StatelessWidget {
  const MajorButton({
    required this.textonButton,
    this.onPress,
    super.key,
  });

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
              Color.fromARGB(255, 9, 150, 92), // Green with 80% opacity
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 50,
            vertical: 20,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Prevents stretching
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
