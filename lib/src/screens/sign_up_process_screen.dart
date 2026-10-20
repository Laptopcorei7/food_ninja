import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';
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
      child: SetupLayout(
        title: 'Your Details',
        intro: 'Your name and number show on your orders, so riders and '
            'restaurants can reach you.',
        onBack: _handleBackPress,
        onButton: _handleNext,
        children: [
          AuthTextField(
            controller: _firstNameController,
            label: 'First name',
            autofillHints: const [AutofillHints.givenName],
          ),
          AuthTextField(
            controller: _lastNameController,
            label: 'Last name',
            autofillHints: const [AutofillHints.familyName],
          ),
          const FieldLabel('Mobile number'),
          // Country button + number formatted for that country as it's
          // typed; the server gets it in +233... form.
          PhoneFormField(
            controller: _phoneController,
            countrySelectorNavigator:
                const CountrySelectorNavigator.draggableBottomSheet(),
            countryButtonStyle: const CountryButtonStyle(
              padding: EdgeInsets.only(left: 16, right: 4),
            ),
            decoration: const InputDecoration(hintText: '24 123 4567'),
            validator: PhoneValidator.validMobile(context),
          ),
        ],
      ),
    );
  }
}
