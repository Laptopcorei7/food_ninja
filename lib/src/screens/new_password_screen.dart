import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/setup_pattern.dart';

/// Forgot password, last step (1.14). [resetToken] comes from the verified
/// code and lives only in this route's argument.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({required this.resetToken, super.key});

  final String resetToken;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _showMessage(
    String title,
    String message, {
    String? imagePath,
    String label = 'Got it',
  }) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppDialog(
          title: title,
          message: message,
          imagePath: imagePath,
          primaryLabel: label,
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );

  Future<void> _handleNext() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      await _showMessage(
        'Missing Fields',
        'Enter your new password in both fields.',
      );
      return;
    }
    if (password != confirm) {
      await _showMessage(
        'Passwords Differ',
        "The two passwords don't match. Check them and try again.",
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      await _authService.resetPassword(widget.resetToken, password, confirm);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await _showMessage(
        'Password Reset',
        'Your password has been changed. Sign in with your new password.',
        imagePath: 'assets/images/success.png',
        label: 'Sign In',
      );
      if (!mounted) return;
      await nav.pushNamedAndRemoveUntil(AppRoutes.signIn, (_) => false);
    } on Object catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      final message = e.toString().replaceAll('Exception: ', '');
      await _showMessage("Couldn't Reset Password", message);
      // The token expired or was used: start again from the method choice.
      if (mounted && message.contains('request a new code')) {
        nav.popUntil(ModalRoute.withName(AppRoutes.forgotPassword));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SetupPattern(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 45,
                          height: 45,
                          child: CustomBackButton(
                            onTap: () => Navigator.maybePop(context),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Reset your password\nhere',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Choose a new password for your account',
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'New Password',
                            suffixIcon: PasswordToggle(
                              obscured: _obscurePassword,
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
                            suffixIcon: PasswordToggle(
                              obscured: _obscureConfirm,
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        Center(
                          child: MajorButton(
                            horizontal: 75,
                            vertical: 23,
                            textonButton: 'Next',
                            onPress: _handleNext,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
