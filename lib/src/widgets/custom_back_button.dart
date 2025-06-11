import 'package:flutter/material.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 248, 235, 217),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(
                0x19000000,
              ),
              offset: Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.chevron_left,
            color: Color(0xFFDA6317),
            size: 28,
          ),
        ),
      ),
    );
  }
}
