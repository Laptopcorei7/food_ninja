import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// Kit 9.4-H: why the user cancels, then 9.4-I. Pops true once the order
/// is cancelled.
class CancelOrderScreen extends StatefulWidget {
  const CancelOrderScreen({required this.order, super.key});

  final PlacedOrder order;

  static const reasons = [
    'I ordered by mistake',
    'I want to change what I ordered',
    'It is taking too long',
    'I need it delivered somewhere else',
    'I found a better price elsewhere',
  ];

  static const other = 'Other';

  @override
  State<CancelOrderScreen> createState() => _CancelOrderScreenState();
}

class _CancelOrderScreenState extends State<CancelOrderScreen> {
  final _note = TextEditingController();
  String? _reason;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      _reason != null &&
      (_reason != CancelOrderScreen.other || _note.text.trim().isNotEmpty);

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final order = await CatalogService().cancelOrder(
        widget.order.id,
        reason: _reason!,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => OrderCancelledScreen(order)),
      );
      navigator.pop(true);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[CancelOrder] failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SheetScaffold(
      title: 'Cancel Order',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Text(
            'The restaurant has not started on '
            '${widget.order.restaurantName ?? 'your order'} yet. Tell us why '
            'you are cancelling.',
            style: TextStyle(fontSize: 16, color: colors.textBody),
          ),
          const SizedBox(height: 8),
          for (final reason in [
            ...CancelOrderScreen.reasons,
            CancelOrderScreen.other,
          ]) ...[
            _ReasonRow(
              label: reason,
              selected: _reason == reason,
              onTap: () => setState(() => _reason = reason),
            ),
            Divider(height: 1, color: colors.divider),
          ],
          if (_reason == CancelOrderScreen.other) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              autofocus: true,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Your reason...'),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: _sending
                ? const CircularProgressIndicator()
                : MajorButton(
                    horizontal: 48,
                    vertical: 12,
                    textonButton: 'Cancel order',
                    onPress: _ready ? _submit : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              KitRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kit 9.4-I: the yellow confirmation after cancelling.
class OrderCancelledScreen extends StatelessWidget {
  const OrderCancelledScreen(this.order, {super.key});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final paid = order.paymentType != null && order.paymentType != 'cash';
    return OutcomePage(
      icon: Icons.close_rounded,
      title: 'Order cancelled',
      message: paid
          ? 'Your order has been cancelled and your payment will be '
              'refunded.'
          : 'Your order has been cancelled.',
      button: 'Back to my orders',
      onButton: () => Navigator.of(context).pop(),
    );
  }
}

/// The kit's yellow result page (4.3-E, 9.4-G, 9.4-I): a ringed icon, a
/// title, a message, optional [extra] and one button.
class OutcomePage extends StatelessWidget {
  const OutcomePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.button,
    required this.onButton,
    this.extra,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String button;
  final VoidCallback onButton;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.header,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.orange, width: 8),
                      ),
                      child: Icon(icon, size: 80, color: AppColors.orange),
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.onHeader,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: colors.onHeader),
                    ),
                    if (extra != null) ...[
                      const SizedBox(height: 40),
                      extra!,
                    ],
                    const SizedBox(height: 40),
                    MajorButton(
                      horizontal: 40,
                      vertical: 12,
                      textonButton: button,
                      onPress: onButton,
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'If you have any questions, contact our support team.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: colors.onHeader),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
