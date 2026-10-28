import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// The latest arrival time across [orders], or null if none has one.
DateTime? _arrivesBy(List<PlacedOrder> orders) {
  final times = orders.map((o) => o.arrivesBy).nonNulls.toList()..sort();
  return times.lastOrNull;
}

String _time(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Shown once the orders are placed (kit 4.3-E): the yellow page with when
/// to expect the food and a way to follow it.
class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({required this.orders, super.key});

  final List<PlacedOrder> orders;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final by = _arrivesBy(orders);
    final n = orders.length;
    void home() => Navigator.of(context).popUntil((route) => route.isFirst);
    return Scaffold(
      backgroundColor: colors.header,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CustomBackButton(onTap: home),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.orange, width: 8),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 80,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: Text(
                        'Order confirmed!',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onHeader,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      n == 1
                          ? 'Your order has been placed.'
                          : 'Your $n orders have been placed. Each restaurant '
                              'sends its own rider.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: colors.onHeader),
                    ),
                    if (by != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Arriving by about ${_time(context, by)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.onHeader,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    MajorButton(
                      horizontal: 40,
                      vertical: 12,
                      textonButton: 'Track my order',
                      onPress: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DeliveryTimeScreen(orders: orders),
                        ),
                      ),
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

/// Where the orders are (kit 4.3-F, without the map until live tracking in
/// phase 6): the address, each restaurant's estimate and its steps. Pull
/// down to refresh.
class DeliveryTimeScreen extends StatefulWidget {
  const DeliveryTimeScreen({required this.orders, super.key});

  final List<PlacedOrder> orders;

  @override
  State<DeliveryTimeScreen> createState() => _DeliveryTimeScreenState();
}

class _DeliveryTimeScreenState extends State<DeliveryTimeScreen> {
  final _catalog = CatalogService();
  late List<PlacedOrder> _orders = widget.orders;

  Future<void> _refresh() async {
    try {
      final fresh = await Future.wait(_orders.map((o) => _catalog.order(o.id)));
      if (mounted) setState(() => _orders = fresh);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[DeliveryTime] refresh failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final address = _orders.firstOrNull?.address?.address;
    return SheetScaffold(
      title: 'Delivery time',
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.orange,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  if (address != null) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        'Delivery address',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.field,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 16, color: colors.textBody),
                      ),
                    ),
                  ],
                  for (final order in _orders) _OrderProgress(order),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: MajorButton(
                      horizontal: 20,
                      vertical: 12,
                      tone: ButtonTone.soft,
                      textonButton: 'Return home',
                      onPress: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: MajorButton(
                      horizontal: 20,
                      vertical: 12,
                      textonButton: 'Track order',
                      onPress: () => Navigator.of(context).pushNamed(
                        AppRoutes.comingSoon,
                        arguments: ('Live tracking', 'phase 6'),
                      ),
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
}

/// One restaurant's order: its estimate and the steps with their times.
class _OrderProgress extends StatelessWidget {
  const _OrderProgress(this.order);

  final PlacedOrder order;

  static const _labels = {
    'placed': 'Order placed',
    'accepted': 'The restaurant accepted your order',
    'preparing': 'The restaurant is preparing your order',
    'on_the_way': 'Your rider is on the way',
    'delivered': 'Your order has been delivered',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = PlacedOrder.steps.indexOf(order.status);
    final cancelled = order.status == 'cancelled';
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ImageIcon(AppIcons.utensils, size: 18, color: colors.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.restaurantName ?? 'Your order',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated delivery',
                  style: TextStyle(fontSize: 16, color: colors.textBody),
                ),
              ),
              if (order.estimatedMinutes case final mins? when !cancelled)
                Text(
                  '$mins mins',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colors.accentText,
                  ),
                ),
            ],
          ),
          Divider(color: colors.divider),
          if (cancelled)
            Text(
              'This order was cancelled.',
              style: TextStyle(fontSize: 16, color: colors.accentText),
            )
          else
            for (final (i, step) in PlacedOrder.steps.indexed)
              _Step(
                label: _labels[step]!,
                at: order.history[step],
                reached: i <= current,
                isCurrent: i == current,
                last: i == PlacedOrder.steps.length - 1,
              ),
        ],
      ),
    );
  }
}

/// A dot on a dotted line, the step's words and the time it happened.
class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.at,
    required this.reached,
    required this.isCurrent,
    required this.last,
  });

  final String label;
  final DateTime? at;
  final bool reached;
  final bool isCurrent;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = reached ? AppColors.orange : colors.soft;
    final text = TextStyle(
      fontSize: 16,
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
      color: reached ? colors.textPrimary : colors.textSecondary,
    );
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: isCurrent ? 14 : 10,
                    height: isCurrent ? 14 : 10,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  if (!last)
                    Expanded(
                      child: VerticalDivider(
                        color: colors.soft,
                        thickness: 2,
                        width: 2,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(label, style: text),
              ),
            ),
            if (at case final at?)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8),
                child: Text(_time(context, at), style: text),
              ),
          ],
        ),
      ),
    );
  }
}
