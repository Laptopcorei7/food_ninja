import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// The cart (kit 4.3-B as a page). Dishes are grouped by restaurant, since
/// each restaurant delivers its own order.
///
/// − and + change the number and the totals at once; the server hears the
/// final quantity [syncDelay] after the last tap, so quick taps never wait.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  static const syncDelay = Duration(milliseconds: 500);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

/// A quantity shown on screen that the server has not confirmed yet.
typedef _Pending = ({String orderId, int qty});

typedef _CartView = ({
  List<CartOrder> orders,
  int count,
  double subTotal,
  double delivery,
});

class _CartScreenState extends State<CartScreen> {
  final _catalog = CatalogService();
  Cart? _cart;
  String? _error;

  /// Line id -> the quantity the user chose, until the server agrees.
  final _pending = <String, _Pending>{};
  final _timers = <String, Timer>{};
  final _inFlight = <String>{};

  /// Lines taken out on screen while the server removes them.
  final _removing = <String>{};

  bool get _saving =>
      _pending.isNotEmpty || _inFlight.isNotEmpty || _removing.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    // Leaving before a change was sent still saves it.
    for (final MapEntry(key: lineId, value: want) in _pending.entries) {
      unawaited(
        _catalog.setCartQty(want.orderId, lineId, want.qty).then(
              (_) {},
              onError: (Object e) => debugPrint('[Cart] save on leave: $e'),
            ),
      );
    }
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
      debugPrint('[Cart] load failed: $e');
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(Exception e) => e.toString().replaceFirst('Exception: ', '');

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  int _qtyOf(CartLine line) => _pending[line.id]?.qty ?? line.qty;

  /// The cart as the user sees it: their unsent quantities and removals
  /// applied to what the server last said.
  _CartView _view(Cart cart) {
    var count = cart.count;
    var change = 0.0;
    var delivery = cart.deliveryCharge;
    final orders = <CartOrder>[];
    for (final order in cart.orders) {
      final lines = <CartLine>[];
      for (final line in order.lines) {
        final qty = _removing.contains(line.id) ? 0 : _qtyOf(line);
        count += qty - line.qty;
        change += (qty - line.qty) * line.price;
        if (qty > 0) lines.add(line);
      }
      if (lines.isEmpty) {
        delivery -= order.deliveryCharge;
      } else {
        orders.add(
          CartOrder(
            id: order.id,
            restaurantName: order.restaurantName,
            lines: lines,
            subTotal: order.subTotal,
            deliveryCharge: order.deliveryCharge,
          ),
        );
      }
    }
    return (
      orders: orders,
      count: count,
      subTotal: cart.subTotal + change,
      delivery: delivery,
    );
  }

  /// Keeps the header badge in step with what the user sees.
  void _publishCount() {
    final cart = _cart;
    if (cart != null) CatalogService.cartCount.value = _view(cart).count;
  }

  void _setQty(CartOrder order, CartLine line, int qty) {
    setState(() => _pending[line.id] = (orderId: order.id, qty: qty));
    _publishCount();
    _timers[line.id]?.cancel();
    _timers[line.id] =
        Timer(CartScreen.syncDelay, () => unawaited(_sync(line.id)));
  }

  /// Sends a line's chosen quantity. Taps during the call are sent after it.
  Future<void> _sync(String lineId) async {
    _timers.remove(lineId);
    final want = _pending[lineId];
    if (want == null || _inFlight.contains(lineId)) return;
    _inFlight.add(lineId);
    try {
      final cart = await _catalog.setCartQty(want.orderId, lineId, want.qty);
      if (!mounted) return;
      setState(() {
        _cart = cart;
        if (_pending[lineId]?.qty == want.qty) _pending.remove(lineId);
      });
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Cart] quantity failed: $e');
      if (!mounted) return;
      setState(() => _pending.remove(lineId));
      _snack(_message(e));
    } finally {
      _inFlight.remove(lineId);
      if (mounted) {
        setState(() {});
        _publishCount();
        if (_pending.containsKey(lineId) && !_timers.containsKey(lineId)) {
          unawaited(_sync(lineId));
        }
      }
    }
  }

  Future<void> _remove(CartOrder order, CartLine line) async {
    _timers.remove(line.id)?.cancel();
    setState(() {
      _pending.remove(line.id);
      _removing.add(line.id);
    });
    _publishCount();
    try {
      final cart = await _catalog.removeCartLine(order.id, line.id);
      if (mounted) setState(() => _cart = cart);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Cart] remove failed: $e');
      if (mounted) _snack(_message(e));
    } finally {
      if (mounted) {
        setState(() => _removing.remove(line.id));
        _publishCount();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(title: 'Cart', child: _body());
  }

  Widget _body() {
    final colors = context.colors;
    final cart = _cart;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
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
    final view = _view(cart);
    if (view.orders.isEmpty) {
      return _Empty(onAdd: () => Navigator.of(context).maybePop());
    }
    final n = view.count;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              Text(
                'You have $n ${n == 1 ? 'item' : 'items'} in your cart',
                style: TextStyle(fontSize: 16, color: colors.textSecondary),
              ),
              for (final order in view.orders) ...[
                const SizedBox(height: 20),
                _RestaurantHeading(order.restaurantName),
                Divider(color: colors.divider),
                for (final line in order.lines) ...[
                  _LineRow(
                    line: line,
                    qty: _qtyOf(line),
                    // A bin while its quantity is on the way would race it.
                    onRemove: _inFlight.contains(line.id)
                        ? null
                        : () => unawaited(_remove(order, line)),
                    onQty: (qty) => _setQty(order, line, qty),
                  ),
                  Divider(color: colors.divider),
                ],
              ],
              const SizedBox(height: 8),
              _Totals(
                subTotal: view.subTotal,
                delivery: view.delivery,
                restaurants: view.orders.length,
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
              textonButton: _saving ? 'Saving…' : 'Checkout',
              // Checkout reads the cart from the server, so wait for it.
              onPress: _saving
                  ? null
                  : () => Navigator.of(context).pushNamed(AppRoutes.checkout),
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 32),
        Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.soft, width: 4),
          ),
          child: ImageIcon(AppIcons.cart, size: 52, color: colors.accentText),
        ),
        const SizedBox(height: 24),
        Text(
          'Your cart is empty',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 32),
        Center(
          child: MajorButton(
            horizontal: 32,
            vertical: 10,
            tone: ButtonTone.soft,
            textonButton: 'Want to add something?',
            onPress: onAdd,
          ),
        ),
      ],
    );
  }
}

class _RestaurantHeading extends StatelessWidget {
  const _RestaurantHeading(this.name);

  final String? name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      header: true,
      child: Row(
        children: [
          ImageIcon(AppIcons.utensils, size: 18, color: colors.accentText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name ?? 'Restaurant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo, name, portion and price, with − qty + under them. At 1 the −
/// becomes a bin that takes the dish out.
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.qty,
    required this.onQty,
    required this.onRemove,
  });

  final CartLine line;
  final int qty;
  final void Function(int qty) onQty;
  final VoidCallback? onRemove;

  static const _maxQty = 99;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final each = [
      if (line.optionName case final o?) o,
      formatCedis(line.price),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox.square(
              dimension: 76,
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
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  each,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                Row(
                  children: [
                    if (qty > 1)
                      _Step(
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        tooltip: 'One less ${line.name}',
                        onTap: () => onQty(qty - 1),
                      )
                    else
                      _Step(
                        icon: const ImageIcon(AppIcons.trash, size: 16),
                        tooltip: 'Remove ${line.name}',
                        onTap: onRemove,
                      ),
                    Semantics(
                      liveRegion: true,
                      label: 'Quantity $qty',
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 30,
                        child: Text(
                          '$qty',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    _Step(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'One more ${line.name}',
                      onTap: qty < _maxQty ? () => onQty(qty + 1) : null,
                    ),
                    // Shrinks on a narrow phone rather than overflow.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCedis(line.price * qty),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.accentText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The kit's orange round − / + buttons.
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tooltip, this.onTap});

  final Widget icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 40, height: 44),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.orange.withValues(alpha: 0.4)
              : AppColors.orange,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        // White on the brand orange reads in both modes.
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: icon,
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.subTotal,
    required this.delivery,
    required this.restaurants,
  });

  final double subTotal;
  final double delivery;
  final int restaurants;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget row(String label, double amount, {bool big = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: big ? 22 : 18,
                    fontWeight: big ? FontWeight.w600 : FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                formatCedis(amount),
                style: TextStyle(
                  fontSize: big ? 22 : 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        );
    return Column(
      children: [
        row('Subtotal', subTotal),
        row(
          restaurants > 1 ? 'Delivery ($restaurants restaurants)' : 'Delivery',
          delivery,
        ),
        Divider(color: colors.divider),
        row('Total', subTotal + delivery, big: true),
      ],
    );
  }
}
