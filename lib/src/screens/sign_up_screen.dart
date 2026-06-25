import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/sign_in_screen.dart';
import 'package:food_ninja/src/screens/sign_up_process_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
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

  bool _keepSignedIn = false;
  bool _emailMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isNavigatingToSignIn = false;

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
          message: "Welcome to Food Ninja! Let's finish setting up your profile.",
          primaryLabel: 'Continue',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );

      if (!mounted) return;
      // pushReplacement removes SignUpScreen from the stack — no stale form to go back to
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SignUpProcessScreen()),
      );
    } catch (e) {
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

  Future<void> _goToSignIn() async {
    setState(() => _isNavigatingToSignIn = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
    );
    if (mounted) setState(() => _isNavigatingToSignIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
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
                width: 236,
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    Image.asset('assets/images/logo.png', height: 203),
                    const SizedBox(height: 20),

                    const Text(
                      'SignUp For Free',
                      style: TextStyle(
                        fontFamily: 'BentonSansBold',
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _usernameField(),
                    const SizedBox(height: 20),
                    _emailField(),
                    const SizedBox(height: 20),
                    _passwordField(),
                    const SizedBox(height: 20),
                    _checkbox(),
                    const SizedBox(height: 45),

                    if (_isLoading)
                      const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF53E88B),
                        ),
                      )
                    else
                      MajorButton(
                        horizontal: 50,
                        vertical: 20,
                        textonButton: 'Create Account',
                        onPress: _handleSignUp,
                      ),

                    const SizedBox(height: 20),
                    _alreadyUser(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _usernameField() {
    return TextField(
      controller: _nameController,
      style: const TextStyle(fontFamily: 'BentonSansRegular'),
      decoration: InputDecoration(
        hintText: 'Name',
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Image.asset('assets/images/profile.png', width: 20, height: 20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4F4F4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4F4F4), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _emailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontFamily: 'BentonSansRegular'),
      decoration: InputDecoration(
        hintText: 'Email',
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/images/email.png', width: 20, height: 20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4F4F4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4F4F4), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _passwordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/images/lock.png', width: 20, height: 20),
        ),
        suffixIcon: IconButton(
          icon: Image.asset(
            _obscurePassword
                ? 'assets/images/hide.png'
                : 'assets/images/show.png',
            width: 20,
            height: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4F4F4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4F4F4), width: 2),
        ),
      ),
    );
  }

  Widget _checkbox() {
    return Column(
      children: [
        Row(
          children: [
            CustomCheckbox(
              value: _keepSignedIn,
              onChanged: (val) => setState(() => _keepSignedIn = val),
            ),
            const SizedBox(width: 8),
            const Text(
              'Keep me signed in',
              style: TextStyle(
                fontFamily: 'BentonSansBook',
                fontWeight: FontWeight.w700,
                color: Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            CustomCheckbox(
              value: _emailMe,
              onChanged: (val) => setState(() => _emailMe = val),
            ),
            const SizedBox(width: 8),
            const Text(
              'Email me about special prices',
              style: TextStyle(
                fontFamily: 'BentonSansBook',
                fontWeight: FontWeight.w700,
                color: Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _alreadyUser() {
    if (_isNavigatingToSignIn) {
      return const SizedBox(
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF53E88B)),
        ),
      );
    }
    return TextButton(
      onPressed: _goToSignIn,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFF53E88B), Color(0xFF15BE77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
        blendMode: BlendMode.srcIn,
        child: const Text(
          'already have an Account?',
          style: TextStyle(
            fontFamily: 'BentonSansMedium',
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class SignupSuccessScreen extends StatelessWidget {
  const SignupSuccessScreen({super.key});

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
              width: 236,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 227),
                Center(
                  child: Image.asset(
                    'assets/images/success.png',
                    fit: BoxFit.cover,
                    height: 162,
                    width: 172,
                  ),
                ),
                const SizedBox(height: 40),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF53E88B), Color(0xFF15BE77)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    'Congrats!',
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'BentonSansBold',
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Your Profile Is Ready For Use',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontFamily: 'BentonSansBold',
                  ),
                ),
                const SizedBox(height: 100),
                MajorButton(
                  horizontal: 50,
                  vertical: 20,
                  textonButton: 'Try Order',
                  onPress: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
