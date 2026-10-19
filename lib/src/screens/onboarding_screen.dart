import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              dark
                  ? 'assets/images/pattern_dark.png'
                  : 'assets/images/pattern.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
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
                        AppColors.green, // Replaces gradient
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
    return _OnboardingPage(
      image: 'assets/images/art_1.png',
      title: 'Find your Comfort\nFood here',
      body:
          'Here You Can find a chef or dish for every\ntaste and color. Enjoy!',
      buttonLabel: 'Next',
      onNext: () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SecondOnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
    );
  }
}

class SecondOnboardingScreen extends StatelessWidget {
  const SecondOnboardingScreen({super.key});

  Future<void> _onNext(BuildContext context) async {
    final nav = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await nav.pushReplacementNamed(AppRoutes.signUp);
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      image: 'assets/images/art_2.png',
      title: 'YumQuick is Where Your\nComfort Food Lives',
      body: 'Enjoy a fast and smooth food delivery at\nyour doorstep',
      buttonLabel: 'Get Started',
      onNext: () => _onNext(context),
    );
  }
}

/// Artwork, title, text and button. The artwork takes whatever height is
/// left, so the page fits short phones without overflowing.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onNext,
  });

  final String image;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              Expanded(child: Image.asset(image, fit: BoxFit.contain)),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 32),
              MajorButton(
                horizontal: 50,
                vertical: 20,
                textonButton: buttonLabel,
                onPress: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
