import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/pattern.png',
              fit: BoxFit.cover,
              height: 812,
              width: 375,
            ),
          ),
          SafeArea(
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: 200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
