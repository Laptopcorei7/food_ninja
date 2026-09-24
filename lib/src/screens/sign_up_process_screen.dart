import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/setup_pattern.dart';
import 'package:phone_form_field/phone_form_field.dart';

class SignUpProcessScreen extends StatefulWidget {
  const SignUpProcessScreen({super.key});

  @override
  State<SignUpProcessScreen> createState() => _SignUpProcessState();
}

class _SignUpProcessState extends State<SignUpProcessScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final _phoneController = PhoneController(
    initialValue: const PhoneNumber(isoCode: IsoCode.GH, nsn: ''),
  );
  final _authService = AuthService();
  final _userService = UserService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
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
    await nav.pushReplacementNamed(AppRoutes.signUp);
  }

  Future<void> _handleNext() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final number = _phoneController.value;
    final phone = number.international;

    if (firstName.isEmpty || lastName.isEmpty || number.nsn.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Missing Fields',
          message:
              'Please fill in your first name, last name, and phone number.',
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }
    if (!number.isValid(type: PhoneNumberType.mobile)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Check Your Number',
          message: "That doesn't look like a mobile number for the country "
              'selected. Check the digits or tap the flag to change country.',
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
      await nav.pushNamed(AppRoutes.verify, arguments: phone);
    } on Object catch (e) {
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
        unawaited(_handleBackPress());
      },
      child: Scaffold(
        body: Stack(
          children: [
            const SetupPattern(),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This data will be displayed in your account profile for security',
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 35),
                      _buildField(_firstNameController, 'First Name'),
                      const SizedBox(height: 25),
                      _buildField(_lastNameController, 'Last Name'),
                      const SizedBox(height: 25),
                      // Country button + number formatted for that country as
                      // it's typed; the server gets it in +233... form.
                      PhoneFormField(
                        controller: _phoneController,
                        countrySelectorNavigator: const CountrySelectorNavigator
                            .draggableBottomSheet(),
                        countryButtonStyle: const CountryButtonStyle(
                          padding: EdgeInsets.only(left: 16, right: 4),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Mobile Number',
                        ),
                        validator: PhoneValidator.validMobile(context),
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

  Widget _buildField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
