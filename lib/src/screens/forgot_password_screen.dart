import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/setup_pattern.dart';
import 'package:phone_form_field/phone_form_field.dart';

/// Forgot password, step 1 (1.13): pick SMS or email and enter the contact.
///
/// The design shows the account's masked contacts, but nobody is signed in
/// here and the server won't say whether an account exists, so each option
/// takes the contact as input instead. [email] prefills the email option.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({this.email, super.key});

  final String? email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(text: widget.email);
  final _phoneController = PhoneController(
    initialValue: const PhoneNumber(isoCode: IsoCode.GH, nsn: ''),
  );
  late String _method = (widget.email?.isNotEmpty ?? false) ? 'email' : 'sms';

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _showError(String title, String message) => showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: title,
          message: message,
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );

  Future<void> _handleNext() async {
    final String contact;
    if (_method == 'sms') {
      final number = _phoneController.value;
      if (!number.isValid(type: PhoneNumberType.mobile)) {
        await _showError(
          'Check Your Number',
          'Enter the mobile number on your account. Tap the flag to change '
              'country.',
        );
        return;
      }
      contact = number.international;
    } else {
      contact = _emailController.text.trim();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(contact)) {
        await _showError(
          'Check Your Email',
          'Enter the email address on your account.',
        );
        return;
      }
    }
    // The verification screen sends the code when it opens.
    await Navigator.pushNamed(
      context,
      AppRoutes.resetCode,
      arguments: (_method, contact),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SetupPattern(),
          SafeArea(
            // Scrolls only when the content does not fit (keyboard open);
            // otherwise Next stays at the bottom.
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 45,
                          height: 45,
                          child: CustomBackButton(
                            onTap: () => Navigator.maybePop(context),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select which contact details should we use to '
                          'reset your password',
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _optionCard(
                          method: 'sms',
                          label: 'Via sms:',
                          icon: Image.asset(
                            'assets/images/message.png',
                            width: 28,
                            height: 28,
                          ),
                          field: PhoneFormField(
                            controller: _phoneController,
                            countrySelectorNavigator:
                                const CountrySelectorNavigator
                                    .draggableBottomSheet(),
                            countryButtonStyle: const CountryButtonStyle(
                              padding: EdgeInsets.only(right: 4),
                            ),
                            decoration: _fieldDecoration('Mobile Number'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _optionCard(
                          method: 'email',
                          label: 'Via email:',
                          icon: Image.asset(
                            'assets/images/email_1.png',
                            width: 28,
                            height: 28,
                          ),
                          field: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: _fieldDecoration('Email'),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The card itself is the input's frame, so the field has no box of its own.
  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  Widget _optionCard({
    required String method,
    required String label,
    required Widget icon,
    required Widget field,
  }) {
    final selected = _method == method;
    final colors = context.colors;

    return Semantics(
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => setState(() => _method = method),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.green : colors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 50)],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                    // Typing in a field also picks its method.
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) setState(() => _method = method);
                      },
                      child: field,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
