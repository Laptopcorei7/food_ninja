import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/setup_pattern.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selected;
  final _userService = UserService();

  // A bank can issue Visa or Mastercard; the brand is detected from the card
  // number when it's entered (phase 5), so the bank option sends no brand.
  static const _options = [
    _PaymentOption(
      id: 'bank',
      label: 'Bank Card',
      icon: Icons.account_balance_outlined,
      type: 'card',
    ),
    _PaymentOption(
      id: 'paypal',
      label: 'PayPal',
      // Full-colour wordmark; null keeps its own two blues in light mode.
      logos: [('assets/images/paypal.png', null)],
      type: 'paypal',
      brand: 'PayPal',
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
      await _userService.addPaymentMethod(option.type, brand: option.brand);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.pushNamed(AppRoutes.uploadPhoto);
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
    return Scaffold(
      body: Stack(
        children: [
          const SetupPattern(),
          SafeArea(
            // Scrolls only when the content does not fit (short phone,
            // keyboard open); otherwise Next stays at the bottom.
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
                          'Payment Method',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This data will be displayed in your account\nprofile for security',
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
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
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(_PaymentOption option) {
    final isSelected = _selected == option.id;
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: GestureDetector(
        onTap: () => setState(() => _selected = option.id),
        child: Container(
          width: double.infinity,
          height: 73,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColors.green : colors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(color: colors.shadow, blurRadius: 50),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              if (option.icon case final icon?) ...[
                Icon(
                  icon,
                  size: 28,
                  color: dark ? Colors.white : AppColors.greenDark,
                ),
                Text(
                  option.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              for (final (path, color) in option.logos)
                Image.asset(
                  path,
                  height: 30,
                  color: dark ? Colors.white : color,
                ),
            ],
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
    required this.type,
    this.logos = const [],
    this.icon,
    this.brand,
  });

  final String id;
  final String label;

  /// Logo asset and its tint in light mode (null = the logo's own colours);
  /// dark mode shows logos white, as in 2.7.
  final List<(String, Color?)> logos;

  /// Shown with [label] when the option has no brand logo.
  final IconData? icon;
  final String type;
  final String? brand;
}
