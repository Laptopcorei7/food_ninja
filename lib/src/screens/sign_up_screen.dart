import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpState();
}

class _SignUpState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Missing Fields',
          message: 'Please fill in your name, email, and password to continue.',
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signup(name, email, password);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppDialog(
          success: true,
          title: 'Account Created!',
          message:
              "Welcome to YumQuick! Let's finish setting up your profile.",
          primaryLabel: 'Continue',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );

      if (!mounted) return;
      // Replace, so there is no stale form to go back to.
      await Navigator.pushReplacementNamed(context, AppRoutes.signUpProcess);
    } on Object catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Sign Up Failed',
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'Try Again',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'New Account',
      children: [
        AuthTextField(
          controller: _nameController,
          label: 'Full name',
          hint: 'Ama Mensah',
          autofillHints: const [AutofillHints.name],
        ),
        AuthTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'example@example.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        AuthTextField(
          controller: _passwordController,
          label: 'Password',
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSignUp(),
          suffix: PasswordToggle(
            obscured: _obscurePassword,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: AppColors.orange)
              : SizedBox(
                  width: 210,
                  child: MajorButton(
                    horizontal: 16,
                    vertical: 10,
                    textonButton: 'Sign Up',
                    onPress: _handleSignUp,
                  ),
                ),
        ),
        const SizedBox(height: 24),
        const SocialSignInButtons(),
        const SizedBox(height: 16),
        AuthLink(
          prefix: 'Already have an account?',
          label: 'Log In',
          onTap: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.signIn),
        ),
      ],
    );
  }
}

/// End of sign-up, in the kit's confirmation style (4.3-E): yellow page,
/// orange ring, short message.
class SignupSuccessScreen extends StatelessWidget {
  const SignupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.header,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const ImageIcon(
                  AppIcons.checkCircle,
                  size: 140,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 32),
                Text(
                  "You're all set!",
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colors.onHeader,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your profile is ready. Find something good near you.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(color: colors.onHeader),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 210,
                  child: MajorButton(
                    horizontal: 16,
                    vertical: 10,
                    textonButton: 'Start Ordering',
                    onPress: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (route) => false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
