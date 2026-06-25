import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/verification_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class SignUpProcessScreen extends StatefulWidget {
  const SignUpProcessScreen({super.key});

  @override
  State<SignUpProcessScreen> createState() => _SignUpProcessState();
}

class _SignUpProcessState extends State<SignUpProcessScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleBackPress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialog(
        title: 'Delete Account?',
        message:
            'Going back will permanently delete your account. You will need to sign up again.',
        primaryLabel: 'Delete & Go Back',
        primaryIsDestructive: true,
        secondaryLabel: 'Stay Here',
        onPrimary: () => Navigator.of(ctx).pop(true),
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );

    if (confirmed != true || !mounted) return;

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    await _authService.deleteAccount();
    if (!mounted) return;
    nav.pop(); // dismiss overlay
    await nav.pushReplacementNamed('/signup');
  }

  Future<void> _handleNext() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _mobileController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Missing Fields',
          message: 'Please fill in your first name, last name, and phone number.',
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      await _userService.updateProfile(firstName, lastName, phone);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => VerificationScreen(phoneNumber: phone),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Error',
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'Try Again',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 249, 249, 253),
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/pattern_2.png',
                fit: BoxFit.cover,
                height: 250,
                width: 200,
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 45,
                        height: 45,
                        child: CustomBackButton(
                          onTap: _handleBackPress,
                        ),
                      ),
                    const SizedBox(height: 32),

                    const Text(
                      'Fill in your bio to get\nstarted',
                      style: TextStyle(
                        fontFamily: 'BentonSansBold',
                        fontSize: 25,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'This data will be displayed in your account profile for security',
                      style: TextStyle(
                        fontFamily: 'BentonSansBook',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 35),

                    _buildField(_firstNameController, 'First Name'),
                    const SizedBox(height: 25),
                    _buildField(_lastNameController, 'Last Name'),
                    const SizedBox(height: 25),
                    _buildField(
                      _mobileController,
                      'Mobile Number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 150),

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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'BentonSansRegular'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'BentonSansRegular',
          color: Colors.grey,
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
