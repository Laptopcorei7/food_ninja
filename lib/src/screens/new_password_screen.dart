import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';

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
    bool success = false,
    String label = 'Got it',
  }) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppDialog(
          title: title,
          message: message,
          success: success,
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
        success: true,
        label: 'Log In',
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
    return SetupLayout(
      title: 'Set Password',
      intro: 'Choose a new password for your account.',
      buttonLabel: 'Create New Password',
      onButton: _handleNext,
      children: [
        AuthTextField(
          controller: _passwordController,
          label: 'Password',
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          suffix: PasswordToggle(
            obscured: _obscurePassword,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        AuthTextField(
          controller: _confirmController,
          label: 'Confirm password',
          obscureText: _obscureConfirm,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleNext(),
          suffix: PasswordToggle(
            obscured: _obscureConfirm,
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ],
    );
  }
}
