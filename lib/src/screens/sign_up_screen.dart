import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
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

  bool _emailMe = false;
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
          imagePath: 'assets/images/success.png',
          title: 'Account Created!',
          message:
              "Welcome to Food Ninja! Let's finish setting up your profile.",
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
      title: 'Sign Up For Free',
      children: [
        AuthTextField(
          controller: _nameController,
          hint: 'Name',
          icon: 'assets/images/profile.png',
        ),
        const SizedBox(height: 12),
        AuthTextField(
          controller: _emailController,
          hint: 'Email',
          icon: 'assets/images/email.png',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          controller: _passwordController,
          hint: 'Password',
          icon: 'assets/images/lock.png',
          obscureText: _obscurePassword,
          suffix: PasswordToggle(
            obscured: _obscurePassword,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CustomCheckbox(
              value: _emailMe,
              onChanged: (val) => setState(() => _emailMe = val),
            ),
            const SizedBox(width: 10),
            Text(
              'Email Me About Special Pricing',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SocialSignInButtons(),
        const SizedBox(height: 24),
        if (_isLoading)
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
          )
        else
          MajorButton(
            horizontal: 40,
            vertical: 18,
            textonButton: 'Create Account',
            onPress: _handleSignUp,
          ),
        const SizedBox(height: 8),
        AuthLink(
          label: 'already have an account?',
          onTap: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.signIn),
        ),
      ],
    );
  }
}

class SignupSuccessScreen extends StatelessWidget {
  const SignupSuccessScreen({super.key});

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
                    'assets/images/success.png',
                    height: 162,
                    width: 172,
                  ),
                  const SizedBox(height: 32),
                  ShaderMask(
                    shaderCallback: AppColors.brandGradient.createShader,
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'Congrats!',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Profile Is Ready To Use',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 80),
                  MajorButton(
                    horizontal: 50,
                    vertical: 18,
                    textonButton: 'Try Order',
                    onPress: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (route) => false,
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
