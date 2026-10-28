import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/add_card_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// The icon for a way to pay: the card brand, the kit's card, phone or
/// PayPal mark, or cash.
class PaymentIcon extends StatelessWidget {
  const PaymentIcon(this.method, {this.size = 30, super.key});

  final PaymentMethod method;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logo = switch (method.brand) {
      'visa' => 'assets/images/visa.png',
      'mastercard' => 'assets/images/mastercard.png',
      _ => null,
    };
    if (method.type == 'card' && logo != null) {
      return Image.asset(
        logo,
        width: size,
        height: size,
        color: colors.textPrimary,
        excludeFromSemantics: true,
      );
    }
    if (method.type == 'cash') {
      return Icon(
        Icons.payments_outlined,
        size: size,
        color: colors.accentText,
      );
    }
    return ImageIcon(
      switch (method.type) {
        'momo' => AppIcons.phone,
        'paypal' => AppIcons.paypal,
        _ => AppIcons.card,
      },
      size: size,
      color: colors.accentText,
    );
  }
}

/// How to pay (kit 4.1.1-L): saved cards and wallets, plus cash on
/// delivery. Tapping one returns it; one chosen at sign-up without its
/// number asks for the number first.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({this.selected, super.key});

  final PaymentMethod? selected;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _catalog = CatalogService();
  List<PaymentMethod>? _methods;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final methods = await _catalog.paymentMethods();
      if (mounted) setState(() => _methods = methods);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[PaymentMethods] load failed: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  bool _isSelected(PaymentMethod m) {
    final selected = widget.selected;
    return selected != null && selected.type == m.type && selected.id == m.id;
  }

  Future<void> _pick(PaymentMethod method) async {
    final nav = Navigator.of(context);
    if (!method.needsDetails) return nav.pop(method);
    await _openForm(method.type, existing: method);
  }

  Future<void> _openForm(String type, {PaymentMethod? existing}) async {
    final nav = Navigator.of(context);
    final saved = await nav.push(
      MaterialPageRoute<PaymentMethod>(
        builder: (_) => type == 'momo'
            ? AddMomoScreen(existingId: existing?.id)
            : AddCardScreen(existingId: existing?.id),
      ),
    );
    if (saved != null && mounted) nav.pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final methods = _methods;
    Widget row(PaymentMethod m) => Column(
          children: [
            ChoiceRow(
              leading: PaymentIcon(m),
              title: m.name,
              subtitle: m.needsDetails
                  ? (m.type == 'momo'
                      ? 'Add your number'
                      : 'Add your card number')
                  : m.masked,
              selected: _isSelected(m),
              onTap: () => unawaited(_pick(m)),
            ),
            Divider(color: colors.divider),
          ],
        );
    return SheetScaffold(
      title: 'Payment methods',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          else if (methods == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            )
          else
            for (final m in methods) row(m),
          row(PaymentMethod.cash),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              MajorButton(
                horizontal: 24,
                vertical: 10,
                tone: ButtonTone.soft,
                textonButton: 'Add card',
                onPress: () => unawaited(_openForm('card')),
              ),
              MajorButton(
                horizontal: 24,
                vertical: 10,
                tone: ButtonTone.soft,
                textonButton: 'Add mobile money',
                onPress: () => unawaited(_openForm('momo')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
