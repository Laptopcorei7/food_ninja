import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/sign_up_screen.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool showLoader = false;

  Route<void> _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // Show logo first
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        showLoader = true;
      });
    });

    // Then navigate to first onboarding screen
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        _createFadeRoute(const FirstOnboardingScreen()),
      );
    });
  }

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 200,
                  ),
                  const SizedBox(height: 25),
                  if (showLoader)
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF53E88B), // Replaces gradient
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FirstOnboardingScreen extends StatelessWidget {
  const FirstOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 40),
          Image.asset(
            'assets/images/art_1.png',
            fit: BoxFit.cover,
            height: 434,
            width: 370,
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'Find your Comfort\nFood here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'BentonSansBold',
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Here You Can find a chef or dish for every\ntaste and color. Enjoy!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'BentonSansBook',
              ),
            ),
          ),
          const SizedBox(height: 35),
          MajorButton(
            horizontal: 50,
            vertical: 20,
            textonButton: 'Next',
            onPress: () {
              Navigator.of(context).push(
                _createFadeRoute(const SecondOnboardingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Route<void> _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}

class SecondOnboardingScreen extends StatelessWidget {
  const SecondOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 40),
          Image.asset(
            'assets/images/art_2.png',
            fit: BoxFit.cover,
            height: 434,
            width: 370,
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'Food Ninja is Where Your\nComfort Food Lives',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'BentonSansBold',
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Enjoy a fast and smooth food delivery at\nyour doorstep',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'BentonSansBook',
              ),
            ),
          ),
          const SizedBox(height: 35),
          MajorButton(
            horizontal: 50,
            vertical: 20,
            textonButton: 'Next',
            onPress: () {
              Navigator.of(context)
                  .push(_createFadeRoute(const SignUpScreen()));
            },
          ),
        ],
      ),
    );
  }

  Route<void> _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
