import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selected;
  final _userService = UserService();

  static const _options = [
    _PaymentOption(
      id: 'paypal',
      label: 'PayPal',
      logoPath: 'assets/images/paypal.png',
      type: 'paypal',
      brand: 'PayPal',
    ),
    _PaymentOption(
      id: 'visa',
      label: 'Visa',
      logoPath: 'assets/images/visa.png',
      type: 'card',
      brand: 'Visa',
    ),
    _PaymentOption(
      id: 'payoneer',
      label: 'Payoneer',
      logoPath: 'assets/images/payoneer.png',
      type: 'payoneer',
      brand: 'Payoneer',
    ),
  ];

  Future<void> _handleNext() async {
    if (_selected == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Select a Method',
          message: 'Please choose a payment method to continue.',
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    final option = _options.firstWhere((o) => o.id == _selected);

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      await _userService.addPaymentMethod(option.type, option.brand, '');
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.push<void>(
        MaterialPageRoute<void>(builder: (_) => const UploadPhotoScreen()),
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
    return Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 45,
                    height: 45,
                    child: CustomBackButton(
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontFamily: 'BentonSansBold',
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'This data will be displayed in your account\nprofile for security',
                    style: TextStyle(
                      fontFamily: 'BentonSansBook',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  ..._options.map(_buildOptionCard),

                  const Spacer(),

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
    );
  }

  Widget _buildOptionCard(_PaymentOption option) {
    final isSelected = _selected == option.id;

    return GestureDetector(
      onTap: () => setState(() => _selected = option.id),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF53E88B) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            option.label,
            style: const TextStyle(
              fontFamily: 'BentonSansBold',
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.id,
    required this.label,
    required this.logoPath,
    required this.type,
    required this.brand,
  });

  final String id;
  final String label;
  final String logoPath;
  final String type;
  final String brand;
}
