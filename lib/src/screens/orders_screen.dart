import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/cancel_order_screen.dart';
import 'package:food_ninja/src/screens/review_screen.dart';
import 'package:food_ninja/src/screens/tracking_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// "29 Nov, 1:20 PM" in the phone's locale.
String formatOrderTime(BuildContext context, DateTime at) {
  final loc = MaterialLocalizations.of(context);
  final time = loc.formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${loc.formatShortMonthDay(at)}, $time';
}

String _items(int n) => '$n item${n == 1 ? '' : 's'}';

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Runs [action], turning an expired session into a sign-out and any other
/// failure into a message. Returns null on failure.
Future<T?> _attempt<T>(
  BuildContext context,
  String what,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on SessionExpiredException {
    if (context.mounted) await signOutExpired(context);
  } on Exception catch (e) {
    debugPrint('[Orders] $what failed: $e');
    if (context.mounted) {
      _say(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
  return null;
}

/// Order again: adds the order's dishes to the cart and offers the cart.
Future<void> reorder(BuildContext context, PlacedOrder order) async {
  final result =
      await _attempt(context, 'reorder', () => CatalogService().reorder(order.id));
  if (result == null || !context.mounted) return;
  final (added, skipped) = result;
  final gone = skipped.isEmpty
      ? ''
      : ' ${skipped.join(', ')} ${skipped.length == 1 ? 'is' : 'are'} no '
          'longer on the menu.';
  if (added == 0) {
    _say(context, 'None of these dishes are on the menu any more.');
    return;
  }
  // The messenger outlives this page; read the navigator now.
  final navigator = Navigator.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        content: Text('Added to your cart.$gone'),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () => navigator.pushNamed(AppRoutes.cart),
        ),
      ),
    );
}

/// Opens Cancel Order. True when the order was cancelled.
Future<bool> openCancel(BuildContext context, PlacedOrder order) async {
  final done = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => CancelOrderScreen(order: order)),
  );
  return done ?? false;
}

Future<void> openTracking(BuildContext context, PlacedOrder order) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveTrackingScreen(order: order),
      ),
    );

/// Opens Leave a Review. True when the review was sent.
Future<bool> openReview(
  BuildContext context,
  PlacedOrder order, {
  int? restaurantRating,
}) async {
  final done = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          ReviewScreen(order: order, restaurantRating: restaurantRating),
    ),
  );
  return done ?? false;
}

/// Kit 9.4-A/B/C: the user's placed orders under Active, Completed and
/// Cancelled. Reloads each time the tab is shown.
class OrdersTab extends StatefulWidget {
  const OrdersTab({required this.active, super.key});

  /// True while this tab is the one on screen.
  final bool active;

  static const tabs = {
    'active': 'Active',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _tab = 'active';
  List<PlacedOrder>? _orders;
  bool _more = false;
  int _page = 1;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(OrdersTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) unawaited(_load());
  }

  /// The first page of [_tab], or the next one when [more].
  Future<void> _load({bool more = false}) async {
    final tab = _tab;
    final page = more ? _page + 1 : 1;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final (orders, hasMore) = await CatalogService().orders(tab, page: page);
      // A tab switch while loading makes this answer stale.
      if (!mounted || tab != _tab) return;
      setState(() {
        _orders = more ? [...?_orders, ...orders] : orders;
        _more = hasMore;
        _page = page;
      });
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Orders] load failed: $e');
      if (mounted && tab == _tab) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && tab == _tab) setState(() => _loading = false);
    }
  }

  void _show(String tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _orders = null;
    });
    unawaited(_load());
  }

  Future<void> _open(PlacedOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );
    if (mounted) await _load();
  }

  /// Runs a row's action, then reloads: it may have moved the order.
  Future<void> _then(Future<Object?> action) async {
    await action;
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'My Orders',
      showBack: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _TabPills(selected: _tab, onSelect: _show),
          ),
          Divider(
            indent: 24,
            endIndent: 24,
            height: 1,
            color: context.colors.divider,
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final orders = _orders;
    if (_error != null && orders == null) {
      return Center(
        child: _Note(
          text: _error!,
          action: TextButton(onPressed: _load, child: const Text('Try again')),
        ),
      );
    }
    if (orders == null) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink();
    }
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _load,
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _Note(
                  text: switch (_tab) {
                    'active' => 'No orders on the way. Your next order '
                        'shows here until it arrives.',
                    'completed' => 'Delivered orders show here.',
                    _ => 'No cancelled orders.',
                  },
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: orders.length + (_more ? 1 : 0),
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.colors.divider),
              itemBuilder: (context, i) {
                if (i == orders.length) {
                  return Center(
                    child: TextButton(
                      onPressed: _loading ? null : () => _load(more: true),
                      child: const Text('Show older orders'),
                    ),
                  );
                }
                final order = orders[i];
                return OrderRow(
                  order: order,
                  onTap: () => _open(order),
                  onCancel: () => _then(openCancel(context, order)),
                  onTrack: () => _then(openTracking(context, order)),
                  onReview: () => _then(openReview(context, order)),
                  onReorder: () => reorder(context, order),
                );
              },
            ),
    );
  }
}

/// The three kit pills: the chosen one orange, the others peach.
class _TabPills extends StatelessWidget {
  const _TabPills({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final MapEntry(key: tab, value: label) in OrdersTab.tabs.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                selected: tab == selected,
                button: true,
                child: Material(
                  color: tab == selected ? AppColors.orange : colors.soft,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(tab),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          color: tab == selected
                              ? Colors.white
                              : colors.accentText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One restaurant's order in the list: first dish photo, restaurant,
/// dishes, when, total, and the buttons for its state.
class OrderRow extends StatelessWidget {
  const OrderRow({
    required this.order,
    required this.onTap,
    required this.onCancel,
    required this.onTrack,
    required this.onReview,
    required this.onReorder,
    super.key,
  });

  final PlacedOrder order;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final VoidCallback onTrack;
  final VoidCallback onReview;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placed = order.placedAt;
    final dishes = order.lines.map((l) => l.name).join(', ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 76,
                height: 96,
                child: FoodPhoto(url: order.lines.firstOrNull?.photoUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          order.restaurantName ?? 'Your order',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCedis(order.total),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: colors.accentText,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dishes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 14, color: colors.textBody),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _items(order.itemCount),
                        style: TextStyle(fontSize: 14, color: colors.textBody),
                      ),
                    ],
                  ),
                  if (placed != null)
                    Text(
                      formatOrderTime(context, placed),
                      style:
                          TextStyle(fontSize: 14, color: colors.textSecondary),
                    ),
                  OrderStatusLine(order: order),
                  const SizedBox(height: 8),
                  _buttons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttons() {
    MajorButton pill(String text, VoidCallback onPress, ButtonTone tone) =>
        MajorButton(
          horizontal: 12,
          vertical: 6,
          textonButton: text,
          onPress: onPress,
          tone: tone,
        );
    final buttons = <Widget>[
      if (order.isActive && order.canCancel)
        pill('Cancel order', onCancel, ButtonTone.primary),
      if (order.isActive) pill('Track', onTrack, ButtonTone.soft),
      if (order.isDelivered && !order.reviewed)
        pill('Leave a review', onReview, ButtonTone.soft),
      if (!order.isActive) pill('Order again', onReorder, ButtonTone.soft),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

/// "Order delivered", "Order cancelled" or where an active order is.
class OrderStatusLine extends StatelessWidget {
  const OrderStatusLine({required this.order, super.key});

  final PlacedOrder order;

  static const labels = {
    'placed': 'Waiting for the restaurant',
    'accepted': 'Accepted by the restaurant',
    'preparing': 'Being prepared',
    'on_the_way': 'On the way',
    'delivered': 'Order delivered',
    'cancelled': 'Order cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = switch (order.status) {
      'delivered' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.highlight_off_rounded,
      _ => Icons.schedule_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.accentText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              labels[order.status] ?? order.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.accentText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kit 9.4-E: what was ordered, where it went, how it was paid and what it
/// cost, with the actions for its state. Placed lines can't change, so the
/// kit's − / + are left out.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({required this.order, super.key});

  final PlacedOrder order;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late PlacedOrder _order = widget.order;

  Future<void> _refresh() async {
    final fresh = await _attempt(
      context,
      'order',
      () => CatalogService().order(_order.id),
    );
    if (fresh != null && mounted) setState(() => _order = fresh);
  }

  Future<void> _then(Future<Object?> action) async {
    await action;
    if (mounted) await _refresh();
  }

  static const _payments = {
    'card': 'Card',
    'momo': 'Mobile money',
    'paypal': 'PayPal',
    'cash': 'Cash on delivery',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = _order;
    final placed = order.placedAt;
    final heading = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
    );
    final body = TextStyle(fontSize: 16, color: colors.textBody);
    final buttons = <Widget>[
      if (order.isActive && order.canCancel)
        MajorButton(
          horizontal: 20,
          vertical: 12,
          tone: ButtonTone.soft,
          textonButton: 'Cancel order',
          onPress: () => _then(openCancel(context, order)),
        ),
      if (order.isActive)
        MajorButton(
          horizontal: 20,
          vertical: 12,
          textonButton: 'Track order',
          onPress: () => _then(openTracking(context, order)),
        ),
      if (order.isDelivered && !order.reviewed)
        MajorButton(
          horizontal: 20,
          vertical: 12,
          tone: ButtonTone.soft,
          textonButton: 'Leave a review',
          onPress: () => _then(openReview(context, order)),
        ),
      if (!order.isActive)
        MajorButton(
          horizontal: 20,
          vertical: 12,
          textonButton: 'Order again',
          onPress: () => reorder(context, order),
        ),
    ];
    return SheetScaffold(
      title: 'Order Details',
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
                  Semantics(
                    header: true,
                    child: Text(
                      order.restaurantName ?? 'Your order',
                      style: heading.copyWith(fontSize: 24),
                    ),
                  ),
                  if (placed != null)
                    Text(formatOrderTime(context, placed), style: body),
                  OrderStatusLine(order: order),
                  if (order.cancelReason case final reason?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Reason: $reason', style: body),
                    ),
                  Divider(height: 32, color: colors.divider),
                  for (final line in order.lines) _Line(line),
                  Divider(height: 32, color: colors.divider),
                  if (order.address?.address case final address?) ...[
                    Text('Delivered to', style: heading),
                    const SizedBox(height: 4),
                    Text(address, style: body),
                    const SizedBox(height: 16),
                  ],
                  if (_payments[order.paymentType] case final payment?) ...[
                    Text('Payment', style: heading),
                    const SizedBox(height: 4),
                    Text(
                      order.isCancelled && order.paymentType != 'cash'
                          ? '$payment, refunded'
                          : payment,
                      style: body,
                    ),
                    Divider(height: 32, color: colors.divider),
                  ],
                  _Money('Subtotal', order.subTotal),
                  _Money('Delivery', order.deliveryCharge),
                  if (order.discount > 0) _Money('Discount', -order.discount),
                  Divider(height: 24, color: colors.divider),
                  _Money('Total', order.total, bold: true),
                ],
              ),
            ),
          ),
          if (buttons.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: buttons,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.line);

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 64,
              child: FoodPhoto(url: line.photoUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  [
                    if (line.optionName case final option?) option,
                    '${line.qty} × ${formatCedis(line.price)}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 14, color: colors.textBody),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatCedis(line.price * line.qty),
            style: TextStyle(fontSize: 16, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money(this.label, this.amount, {this.bold = false});

  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 20 : 17,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: context.colors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            amount < 0 ? '− ${formatCedis(-amount)}' : formatCedis(amount),
            style: style,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.colors.textSecondary,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
