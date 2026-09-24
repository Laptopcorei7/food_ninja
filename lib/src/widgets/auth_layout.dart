import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// Pattern header, logo and title shared by sign in and sign up (1.4, 1.5).
///
/// Both screens draw the header in the same place, so when one fades in over
/// the other the header looks still. The title and form below it slide up and
/// fade in with the route animation.
class AuthLayout extends StatelessWidget {
  const AuthLayout({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final form = CurvedAnimation(
      parent: ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
      curve: Curves.easeOutCubic,
    );

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 16, 25, 16),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', height: 140),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: form,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(form),
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ...children,
                        ],
                      ),
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

/// Text field with the green icon in front, as in 1.5.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final String icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Image.asset(icon, width: 22, height: 22),
        ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: suffix,
      ),
    );
  }
}

/// Eye button that shows or hides the password.
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({
    required this.obscured,
    required this.onPressed,
    super.key,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Image.asset(
        obscured ? 'assets/images/hide.png' : 'assets/images/show.png',
        width: 20,
        height: 20,
        // The eye icons are single-colour; tint them so they show in dark mode.
        color: context.colors.textPrimary.withValues(alpha: 0.5),
      ),
    );
  }
}

/// "Or Continue With" and the Facebook and Google buttons.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Or Continue With',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _button(context, 'Facebook', 'assets/images/facebook.png'),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _button(context, 'Google', 'assets/images/google.png'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _button(BuildContext context, String label, String iconPath) {
    final colors = context.colors;
    return OutlinedButton.icon(
      // Social sign in is not built yet.
      onPressed: () {},
      icon: Image.asset(iconPath, height: 25, width: 25),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

/// Green underlined link used under the auth forms.
class AuthLink extends StatelessWidget {
  const AuthLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.greenDark,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.greenDark,
        ),
      ),
    );
  }
}
