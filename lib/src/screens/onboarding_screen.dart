import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/yumquick_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 0-A: the yellow logo screen, shown while the app checks the saved login.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.yellow,
        body: Center(child: YumQuickLogo()),
      ),
    );
  }
}

/// 1-A to 1-C, on first launch only. Skip or Get Started opens the welcome
/// screen and remembers that onboarding was seen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_PageData> _pages = [
    (
      image: 'assets/images/onboarding_1.jpg',
      icon: AppIcons.orderSwap,
      title: 'Order For Food',
      body: 'Browse dishes from restaurants near you and order in a few taps.',
    ),
    (
      image: 'assets/images/onboarding_2.jpg',
      icon: AppIcons.card,
      title: 'Easy Payment',
      body: 'Pay by card or PayPal, and see the full price before you order.',
    ),
    (
      image: 'assets/images/onboarding_3.jpg',
      icon: AppIcons.rider,
      title: 'Fast Delivery',
      body: 'Only restaurants that can reach you, brought to your door.',
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final nav = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await nav.pushReplacementNamed(AppRoutes.welcome);
  }

  void _next() {
    if (_page == _pages.length - 1) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final last = _page == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.header,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: colors.background,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      PageView(
                        controller: _controller,
                        onPageChanged: (i) => setState(() => _page = i),
                        children: [for (final p in _pages) _Page(page: p)],
                      ),
                      if (!last)
                        Positioned(
                          top: 4,
                          right: 8,
                          child: TextButton.icon(
                            onPressed: _finish,
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                            ),
                            label: const Text('Skip'),
                            style: TextButton.styleFrom(
                              // White pill so it reads on any photo.
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.85,
                              ),
                              foregroundColor: AppColors.light.accentText,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _Dots(count: _pages.length, current: _page),
                const SizedBox(height: 24),
                MajorButton(
                  horizontal: 40,
                  vertical: 10,
                  textonButton: last ? 'Get Started' : 'Next',
                  onPress: _next,
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _PageData = ({
  String image,
  AssetImage icon,
  String title,
  String body,
});

class _Page extends StatelessWidget {
  const _Page({required this.page});

  final _PageData page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        // The photo takes what is left, so short phones don't overflow.
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(page.image, fit: BoxFit.cover),
              // The sheet's rounded top edge, cut into the photo.
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: 31,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              ImageIcon(page.icon, size: 44, color: AppColors.orange),
              const SizedBox(height: 16),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                page.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The kit's page dashes: the current one orange, the rest cream.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 24 : 16,
              height: 4,
              decoration: BoxDecoration(
                color: i == current ? AppColors.orange : context.colors.field,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// 0-B: orange screen with the logo, Log In and Sign Up.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.orange,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                children: [
                  const YumQuickLogo(onOrange: true),
                  const SizedBox(height: 24),
                  // Large bold white on orange: 3.6:1 passes for large text.
                  const Text(
                    'Food from restaurants near you, delivered fast.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 210,
                    child: MajorButton(
                      horizontal: 16,
                      vertical: 10,
                      textonButton: 'Log In',
                      tone: ButtonTone.yellow,
                      onPress: () =>
                          Navigator.pushNamed(context, AppRoutes.signIn),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 210,
                    child: MajorButton(
                      horizontal: 16,
                      vertical: 10,
                      textonButton: 'Sign Up',
                      tone: ButtonTone.cream,
                      onPress: () =>
                          Navigator.pushNamed(context, AppRoutes.signUp),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
