import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/src/screens/delivery_address_screen.dart';
import 'package:food_ninja/src/screens/order_placed_screen.dart';
import 'package:food_ninja/src/screens/payment_methods_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// Checkout (kit 4.3-C and 4.3-D on one page): where to deliver, what is
/// ordered, how to pay, a voucher, and the totals. Placing it places every
/// restaurant's order at once.
///
/// The address starts at the phone's current position, since the user
/// moves between home and work; saved addresses are a tap away.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _catalog = CatalogService();
  final _location = LocationService();
  final _voucherField = TextEditingController();
  StreamSubscription<DeliveryAddress>? _gps;

  Cart? _cart;
  String? _error;

  DeliveryAddress? _address;
  bool _findingAddress = true;

  /// True once the user picks an address; GPS stops replacing it.
  bool _addressPicked = false;

  PaymentMethod? _payment;
  VoucherCheck? _voucher;
  String? _voucherError;
  bool _checkingVoucher = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadPayment());
    _gps = _location.currentAddress().listen(
      (found) {
        if (!_addressPicked) setState(() => _address = found);
      },
      onError: (Object e) => debugPrint('[Checkout] GPS: $e'),
      onDone: () => unawaited(_addressFallback()),
    );
  }

  @override
  void dispose() {
    unawaited(_gps?.cancel());
    _voucherField.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final cart = await _catalog.cart();
      if (mounted) setState(() => _cart = cart);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Checkout] load failed: $e');
      if (mounted) setState(() => _error = _message(e));
    }
  }

  /// Without GPS: the first saved address, else the sign-up one.
  Future<void> _addressFallback() async {
    if (!mounted) return;
    if (_address != null || _addressPicked) {
      return setState(() => _findingAddress = false);
    }
    DeliveryAddress? found;
    try {
      found = (await _catalog.addresses()).firstOrNull ??
          await _location.signUpAddress();
    } on Exception catch (e) {
      debugPrint('[Checkout] no fallback address: $e');
    }
    if (!mounted) return;
    setState(() {
      if (!_addressPicked) _address ??= found;
      _findingAddress = false;
    });
  }

  /// The first saved method that is ready to use, else cash.
  Future<void> _loadPayment() async {
    var choice = PaymentMethod.cash;
    try {
      final methods = await _catalog.paymentMethods();
      choice = methods.where((m) => !m.needsDetails).firstOrNull ?? choice;
    } on Exception catch (e) {
      debugPrint('[Checkout] payment methods failed: $e');
    }
    if (mounted) setState(() => _payment ??= choice);
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push(
      MaterialPageRoute<DeliveryAddress>(
        builder: (_) => DeliveryAddressScreen(selected: _address),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _address = picked;
      _addressPicked = true;
      _findingAddress = false;
    });
  }

  Future<void> _pickPayment() async {
    final picked = await Navigator.of(context).push(
      MaterialPageRoute<PaymentMethod>(
        builder: (_) => PaymentMethodsScreen(selected: _payment),
      ),
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  Future<void> _applyVoucher() async {
    final code = _voucherField.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checkingVoucher = true;
      _voucherError = null;
    });
    try {
      final check = await _catalog.checkVoucher(code);
      if (mounted) setState(() => _voucher = check);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Checkout] voucher refused: $e');
      if (mounted) setState(() => _voucherError = _message(e));
    } finally {
      if (mounted) setState(() => _checkingVoucher = false);
    }
  }

  void _removeVoucher() => setState(() {
        _voucher = null;
        _voucherField.clear();
      });

  Future<void> _place() async {
    final address = _address;
    final payment = _payment;
    if (address == null || payment == null) return;
    setState(() => _placing = true);
    final nav = Navigator.of(context);
    try {
      final orders = await _catalog.placeOrder(
        address: address,
        payment: payment,
        voucherCode: _voucher?.code,
      );
      if (!mounted) return;
      // The cart and checkout are done with; back from here goes Home.
      await nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OrderConfirmedScreen(orders: orders),
        ),
        (route) => route.isFirst,
      );
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Checkout] place failed: $e');
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_message(e))));
      // The cart may have changed (the server says 409); show it as it is.
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(title: 'Checkout', child: _body());
  }

  Widget _body() {
    final colors = context.colors;
    final cart = _cart;
    if (_error case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (cart == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
    }
    if (cart.isEmpty) {
      return Center(
        child: Text(
          'Your cart is empty.',
          style: TextStyle(fontSize: 18, color: colors.textSecondary),
        ),
      );
    }
    final voucher = _voucher;
    final total = voucher?.total ?? cart.total;
    final ready = _address != null && _payment != null && !_placing;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              _Heading(
                'Delivery address',
                action: 'Change',
                actionHint: 'Change delivery address',
                onAction: _pickAddress,
              ),
              const SizedBox(height: 8),
              _Pill(
                child: Text(
                  _address?.address ??
                      (_findingAddress
                          ? 'Finding your location…'
                          : 'Tap Change to choose where to deliver'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: colors.textBody),
                ),
              ),
              if (_address?.label case final label?)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              _Rule(colors.divider),
              _Heading(
                'Order summary',
                action: 'Edit',
                actionHint: 'Edit cart',
                onAction: () => Navigator.of(context).maybePop(),
              ),
              for (final order in cart.orders) _OrderSummary(order),
              _Rule(colors.divider),
              _Heading(
                'Payment method',
                action: 'Change',
                actionHint: 'Change payment method',
                onAction: _pickPayment,
              ),
              const SizedBox(height: 8),
              if (_payment case final payment?)
                Row(
                  children: [
                    PaymentIcon(payment),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        payment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (payment.masked case final masked?)
                      _Pill(
                        dense: true,
                        child: Text(
                          masked,
                          style: TextStyle(color: colors.textBody),
                        ),
                      ),
                  ],
                )
              else
                const LinearProgressIndicator(color: AppColors.orange),
              _Rule(colors.divider),
              const _Heading('Voucher'),
              const SizedBox(height: 8),
              if (voucher != null)
                _AppliedVoucher(voucher: voucher, onRemove: _removeVoucher)
              else
                _VoucherEntry(
                  controller: _voucherField,
                  checking: _checkingVoucher,
                  onApply: _applyVoucher,
                ),
              if (_voucherError case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    style: TextStyle(color: colors.accentText, fontSize: 15),
                  ),
                ),
              _Rule(colors.divider),
              _MoneyRow('Subtotal', cart.subTotal),
              _MoneyRow(
                cart.orders.length > 1
                    ? 'Delivery (${cart.orders.length} restaurants)'
                    : 'Delivery',
                cart.deliveryCharge,
              ),
              if (voucher != null)
                _MoneyRow('Voucher', -voucher.discount, accent: true),
              Divider(color: colors.divider),
              _MoneyRow('Total', total, big: true),
              if (_payment?.type == 'cash')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Pay the rider when your food arrives.',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: MajorButton(
              horizontal: 48,
              vertical: 12,
              textonButton: _placing ? 'Placing order…' : 'Place order',
              onPress: ready ? _place : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.action, this.actionHint, this.onAction});

  final String title;
  final String? action;
  final String? actionHint;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        if (action case final label?)
          Semantics(
            button: true,
            label: actionHint ?? label,
            excludeSemantics: true,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.accentText,
                backgroundColor: colors.soft,
                shape: const StadiumBorder(),
                minimumSize: const Size(64, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(label),
            ),
          ),
      ],
    );
  }
}

/// The kit's cream rounded box for a value (address, card digits).
class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.dense = false});

  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dense ? null : double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : 18,
        vertical: dense ? 6 : 14,
      ),
      decoration: BoxDecoration(
        color: context.colors.field,
        borderRadius: BorderRadius.circular(30),
      ),
      child: child,
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Divider(color: color, height: 1),
      );
}

/// A restaurant and its dishes: "2 × Jollof Rice (Large)    GH₵ 90".
class _OrderSummary extends StatelessWidget {
  const _OrderSummary(this.order);

  final CartOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ImageIcon(AppIcons.utensils, size: 16, color: colors.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.restaurantName ?? 'Restaurant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${line.qty} ×',
                    style: TextStyle(fontSize: 15, color: colors.accentText),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        line.name,
                        if (line.optionName case final o?) '($o)',
                      ].join(' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: colors.textBody),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCedis(line.price * line.qty),
                    style: TextStyle(fontSize: 15, color: colors.textBody),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VoucherEntry extends StatelessWidget {
  const _VoucherEntry({
    required this.controller,
    required this.checking,
    required this.onApply,
  });

  final TextEditingController controller;
  final bool checking;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onApply(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            ],
            decoration: const InputDecoration(
              hintText: 'Voucher code',
              prefixIcon: ImageIcon(AppIcons.discount, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        MajorButton(
          horizontal: 20,
          vertical: 10,
          tone: ButtonTone.soft,
          textonButton: checking ? 'Checking…' : 'Apply',
          onPress: checking ? null : onApply,
        ),
      ],
    );
  }
}

class _AppliedVoucher extends StatelessWidget {
  const _AppliedVoucher({required this.voucher, required this.onRemove});

  final VoucherCheck voucher;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        ImageIcon(AppIcons.discount, size: 22, color: colors.accentText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                voucher.code,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              if (voucher.title.isNotEmpty)
                Text(
                  voucher.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove voucher',
          onPressed: onRemove,
          icon: ImageIcon(
            AppIcons.closeCircle,
            size: 22,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(
    this.label,
    this.amount, {
    this.big = false,
    this.accent = false,
  });

  final String label;
  final double amount;
  final bool big;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextStyle(
      fontSize: big ? 22 : 18,
      fontWeight: big ? FontWeight.w600 : FontWeight.w500,
      color: accent ? colors.accentText : colors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            amount < 0 ? '− ${formatCedis(-amount)}' : formatCedis(amount),
            style: style.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
