import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInState();
}

class _SignInState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepSignedIn = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.login(email, password, keepSignedIn: _keepSignedIn);
      // An account that quit sign-up partway resumes at its first missing
      // step. The login response uses another shape, so ask users/me.
      var (route, arg) = (AppRoutes.home, null as Object?);
      try {
        final user = await UserService().getMe();
        (route, arg) = AppRoutes.setupStepFor(user) ?? (route, arg);
      } on Exception catch (e) {
        debugPrint('[SignIn] profile check failed, opening home: $e');
      }
      if (!mounted) return;
      await Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (_) => false,
        arguments: arg,
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Login To Your Account',
      children: [
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
        const SizedBox(height: 8),
        Row(
          children: [
            CustomCheckbox(
              value: _keepSignedIn,
              onChanged: (val) => setState(() => _keepSignedIn = val),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keep Me Signed In',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ),
            AuthLink(
              label: 'Forgot Password?',
              // TODO(dev): phase 2, navigate to the forgot password flow.
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SocialSignInButtons(),
        const SizedBox(height: 24),
        if (_isLoading)
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.green),
          )
        else
          MajorButton(
            horizontal: 50,
            vertical: 18,
            textonButton: 'Login',
            onPress: _handleLogin,
          ),
        const SizedBox(height: 8),
        AuthLink(
          label: "Don't have an account? Sign Up",
          onTap: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.signUp),
        ),
      ],
    );
  }
}
