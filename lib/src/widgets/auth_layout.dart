import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// Kit page shape for sign in and sign up (2-A, 2-C): header title, then a
/// scrolling form on the sheet. Sign in and sign up fade into each other, so
/// the header looks still while the form slides up.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.children,
    this.heading,
    this.intro,
    super.key,
  });

  /// In the header: "Log In", "New Account".
  final String title;

  /// Large text at the top of the sheet: "Welcome".
  final String? heading;
  final String? intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final form = CurvedAnimation(
      parent: ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
      curve: Curves.easeOutCubic,
    );
    return SheetScaffold(
      title: title,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
        child: FadeTransition(
          opacity: form,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(form),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (heading != null) ...[
                  Text(heading!, style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                ],
                if (intro != null) ...[
                  Text(intro!, style: textTheme.bodyMedium),
                  const SizedBox(height: 24),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The kit's field: a label above a cream box.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen readers get the label on the field itself (below), not
          // twice. The eye button stays its own node.
          ExcludeSemantics(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              autofillHints: autofillHints,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange eye that shows or hides the password.
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
      icon: ImageIcon(
        obscured ? AppIcons.eyeOff : AppIcons.eye,
        size: 22,
        color: AppColors.orange,
      ),
    );
  }
}

/// "or sign up with" and the round Google and Facebook buttons.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('or sign up with', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _button(context, 'Google', AppIcons.google),
            const SizedBox(width: 8),
            _button(context, 'Facebook', AppIcons.facebook),
          ],
        ),
      ],
    );
  }

  Widget _button(BuildContext context, String name, AssetImage icon) {
    return IconButton(
      tooltip: 'Continue with $name',
      // Social sign in is not built yet; say so instead of doing nothing.
      onPressed: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$name sign in is coming soon.')),
        ),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.soft,
        fixedSize: const Size.square(44),
      ),
      icon: ImageIcon(icon, size: 22, color: AppColors.orange),
    );
  }
}

/// "Don't have an account? Sign Up": plain text, then an orange link.
class AuthLink extends StatelessWidget {
  const AuthLink({
    required this.label,
    required this.onTap,
    this.prefix,
    super.key,
  });

  final String? prefix;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prefix != null)
          Flexible(
            child: Text(prefix!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: colors.accentText,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 40),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
