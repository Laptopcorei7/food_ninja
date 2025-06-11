import 'package:flutter/material.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpState();
}

bool _keepSignedIn = false;
bool _emailMe = false;
bool _obscurePassword = true;

class _SignUpState extends State<SignUpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo.png',
                    height: 203,
                  ),
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

                  const MajorButton(
                    horizontal: 50,
                    vertical: 20,
                    textonButton: 'Create Account',
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () {},
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF53E88B), Color(0xFF15BE77)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
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
                  ),
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
      style: const TextStyle(
        fontFamily: 'BentonSansRegular',
      ),
      decoration: InputDecoration(
        hintText: 'Name',
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/profile.png',
            width: 20,
            height: 20,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF4F4F4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF4F4F4),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _emailField() {
    return TextField(
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        fontFamily: 'BentonSansRegular',
      ),
      decoration: InputDecoration(
        hintText: 'Email',
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/email.png',
            width: 20,
            height: 20,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF4F4F4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF4F4F4),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _passwordField() {
    return TextField(
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/lock.png',
            width: 20,
            height: 20,
          ),
        ),
        suffixIcon: IconButton(
          icon: Image.asset(
            _obscurePassword
                ? 'assets/images/hide.png'
                : 'assets/images/show.png',
            width: 20,
            height: 20,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF4F4F4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF4F4F4),
            width: 2,
          ), // When focused
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
}
