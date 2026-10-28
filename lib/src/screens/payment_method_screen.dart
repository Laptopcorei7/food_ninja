import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';

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
      label: 'Bank card',
      icon: AppIcons.card,
      type: 'card',
    ),
    _PaymentOption(
      id: 'paypal',
      label: 'PayPal',
      logo: 'assets/images/paypal.png',
      type: 'paypal',
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
      await _userService.addPaymentMethod(option.type);
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
    return SetupLayout(
      title: 'Payment Method',
      intro: 'How would you like to pay? You can add more ways later.',
      onButton: _handleNext,
      children: [
        const Divider(),
        for (final option in _options) ...[
          _buildOptionRow(option),
          const Divider(),
        ],
      ],
    );
  }

  /// One row of the kit's list (4.1.1-L): icon, name, round selector.
  Widget _buildOptionRow(_PaymentOption option) {
    final isSelected = _selected == option.id;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      label: option.label,
      excludeSemantics: true,
      onTap: () => setState(() => _selected = option.id),
      // Inset and rounded so the tap ripple is a soft pill, not a hard
      // rectangle between the dividers.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: () => setState(() => _selected = option.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (option.icon case final icon?) ...[
                  ImageIcon(icon, size: 32, color: AppColors.orange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
                if (option.logo case final logo?)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // Full-colour wordmark (the user's choice), white in dark
                      // mode.
                      child: Image.asset(
                        logo,
                        height: 26,
                        color: dark ? Colors.white : null,
                      ),
                    ),
                  ),
                KitRadio(selected: isSelected),
              ],
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
    required this.type,
    this.icon,
    this.logo,
  });

  final String id;
  final String label;

  /// Kit icon shown with [label].
  final AssetImage? icon;

  /// Brand wordmark shown instead of icon and label.
  final String? logo;
  final String type;
}
