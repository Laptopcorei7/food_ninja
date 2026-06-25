import 'package:flutter/material.dart';

// Placeholder home screen — will be replaced with the full home UI
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Home Screen\n(coming soon)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'BentonSansBold',
            fontSize: 22,
            color: Color(0xFF53E88B),
          ),
        ),
      ),
    );
  }
}
