import 'package:flutter/material.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/pattern.png',
              fit: BoxFit.cover,
              height: 812,
              width: 375, // adjust to match your Figma design
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo.png', // Replace with your logo asset
                    height: 203,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Login To Your Account',
                    style: TextStyle(
                      fontFamily: 'BentonSansBold',
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Input
                  TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: const TextStyle(
                        fontFamily: 'BentonSansRegular',
                        color: Colors.grey,
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
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        fontFamily: 'BentonSansRegular',
                        color: Colors.grey,
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
                  ),
                  const SizedBox(height: 16),

                  // Social Text
                  const Text(
                    'Or Continue With',
                    style: TextStyle(
                      fontFamily: 'BentonSansBold',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Social Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      socialButton('Facebook', 'assets/images/facebook.png'),
                      const SizedBox(width: 16),
                      socialButton('Google', 'assets/images/google.png'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Forgot Password
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Forgot Your Password?',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.green,
                        fontFamily: 'BentonSansMedium',
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Button
                  const SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: MajorButton(
                        textonButton: 'Login',
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

  Widget socialButton(String label, String iconPath) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Image.asset(
        iconPath,
        height: 25,
        width: 25,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'BentonSansMedium',
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFF4F4F4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(100, 50), // width, height (adjust as needed)
      ),
    );
  }
}
