import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:food_ninja/src/screens/cancel_order_screen.dart';
import 'package:food_ninja/src/screens/chat_screen.dart';
import 'package:food_ninja/src/screens/orders_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/open_link.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';
import 'package:latlong2/latlong.dart';

LatLng _latLng(GeoPoint p) => LatLng(p.lat, p.lng);

/// The part of [route] still ahead of [rider]: from the rider's spot on the
/// nearest stretch of road to the end. Flat lat/lng maths is close enough
/// inside one town.
@visibleForTesting
List<GeoPoint> routeAhead(List<GeoPoint> route, GeoPoint? rider) {
  if (rider == null || route.length < 2) return route;
  var best = 0;
  var bestDist = double.infinity;
  var bestPoint = route.first;
  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];
    final dx = b.lng - a.lng;
    final dy = b.lat - a.lat;
    final len = dx * dx + dy * dy;
    final t = len == 0
        ? 0.0
        : (((rider.lng - a.lng) * dx + (rider.lat - a.lat) * dy) / len)
            .clamp(0.0, 1.0);
    final p = (lat: a.lat + dy * t, lng: a.lng + dx * t);
    final d = (p.lat - rider.lat) * (p.lat - rider.lat) +
        (p.lng - rider.lng) * (p.lng - rider.lng);
    if (d < bestDist) {
      bestDist = d;
      best = i;
      bestPoint = p;
    }
  }
  final rest = route.sublist(best + 1);
  // On a corner the spot is that corner; do not list it twice.
  return rest.first == bestPoint ? rest : [bestPoint, ...rest];
}

/// Kit 9.4-F: the restaurant, the address and the rider on a map, asked
/// for every [LiveTrackingScreen.every]. Turns into Order Delivered when
/// the rider arrives.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({required this.order, super.key});

  final PlacedOrder order;

  static const every = Duration(seconds: 5);

  /// Map tiles come from the network; tests switch them off.
  @visibleForTesting
  static bool showTiles = true;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _catalog = CatalogService();
  OrderTracking? _tracking;
  String? _error;
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _timer = Timer.periodic(LiveTrackingScreen.every, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_leaving) return;
    try {
      final tracking = await _catalog.tracking(widget.order.id);
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _error = null;
      });
      if (tracking.status == 'delivered') await _delivered();
      if (tracking.status == 'cancelled') _timer?.cancel();
    } on SessionExpiredException {
      _timer?.cancel();
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Tracking] poll failed: $e');
      // Keep the last position on screen; the next poll may work.
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _delivered() async {
    _leaving = true;
    _timer?.cancel();
    var order = widget.order;
    try {
      order = await _catalog.order(order.id);
    } on Exception catch (e) {
      // The order passed in still has its dishes, enough to rate them.
      debugPrint('[Tracking] delivered order reload failed: $e');
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => OrderDeliveredScreen(order)),
    );
  }

  void _call(String phone) =>
      openLink(context, Uri(scheme: 'tel', path: phone));

  void _message(OrderTracking t) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen.rider(
            orderId: widget.order.id,
            riderName: t.riderName,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    return SheetScaffold(
      title: 'Live Tracking',
      child: tracking == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
            )
          : LayoutBuilder(
              builder: (context, box) => ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  if (tracking.restaurant != null ||
                      tracking.destination != null)
                    SizedBox(
                      height: (box.maxHeight * 0.55).clamp(220, 460),
                      child: _map(tracking),
                    ),
                  const SizedBox(height: 20),
                  _Progress(order: widget.order, tracking: tracking),
                ],
              ),
            ),
    );
  }

  Widget _map(OrderTracking t) {
    // The road can bend outside the box of the three pins; frame it too.
    final points = [t.restaurant, t.destination, t.rider, ...t.route].nonNulls
        .map(_latLng)
        .toList();
    final colors = context.colors;
    Marker pin(GeoPoint p, Widget child, String label) => Marker(
          point: _latLng(p),
          width: 44,
          height: 44,
          child: Semantics(label: label, child: child),
        );
    Widget badge(Widget icon) => DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.orange, width: 2),
          ),
          child: Center(child: icon),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(48),
                maxZoom: 16,
              ),
              backgroundColor: colors.field,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              if (LiveTrackingScreen.showTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.verygoodcore.food_ninja',
                ),
              if (t.route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeAhead(t.route, t.rider)
                          .map(_latLng)
                          .toList(),
                      color: AppColors.brown,
                      strokeWidth: 4,
                    ),
                  ],
                )
              // Without a road from the server, a straight line still shows
              // the direction.
              else if ((t.restaurant, t.destination)
                  case (final from?, final to?))
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_latLng(from), _latLng(to)],
                      color: AppColors.brown,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (t.restaurant case final p?)
                    pin(
                      p,
                      badge(
                        const ImageIcon(
                          AppIcons.utensils,
                          size: 20,
                          color: AppColors.orange,
                        ),
                      ),
                      t.restaurantName ?? 'Restaurant',
                    ),
                  if (t.destination case final p?)
                    pin(
                      p,
                      const Icon(
                        Icons.location_on,
                        size: 44,
                        color: AppColors.orange,
                      ),
                      'Your address',
                    ),
                  if (t.rider case final p?)
                    pin(
                      p,
                      badge(
                        const Icon(
                          Icons.delivery_dining,
                          size: 26,
                          color: AppColors.orange,
                        ),
                      ),
                      'Your rider',
                    ),
                ],
              ),
            ],
          ),
          // OpenStreetMap's tile policy requires this credit on the map.
          if (LiveTrackingScreen.showTiles)
            Positioned(
              top: 0,
              right: 0,
              child: ColoredBox(
                color: colors.surface.withValues(alpha: 0.8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          if (t.rider != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (t.riderPhone case final phone?) ...[
                    _ContactButton(
                      label: 'Call your rider',
                      icon: Icons.call_outlined,
                      onTap: () => _call(phone),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _ContactButton(
                    label: 'Message your rider',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () => _message(t),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the order is in words, when it should arrive, and the kit's bar
/// with the rider riding along it.
class _Progress extends StatelessWidget {
  const _Progress({required this.order, required this.tracking});

  final PlacedOrder order;
  final OrderTracking tracking;

  static const _status = {
    'placed': 'Waiting for the restaurant to accept',
    'accepted': 'The restaurant accepted your order',
    'preparing': 'The restaurant is preparing your order',
    'on_the_way': 'Your rider is on the way',
    'delivered': 'Your order has arrived',
    'cancelled': 'This order was cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final eta = tracking.etaMinutes;
    final arrives =
        eta == null ? null : DateTime.now().add(Duration(minutes: eta));
    final placed = order.placedAt;
    final small = TextStyle(fontSize: 14, color: colors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.restaurantName ?? tracking.restaurantName ?? 'Your order',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, color: colors.textBody),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            _status[tracking.status] ?? tracking.status,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (eta != null && tracking.status != 'cancelled')
          Text(
            eta <= 1 ? 'Arriving now' : 'Arriving in about $eta mins',
            style: TextStyle(fontSize: 18, color: colors.accentText),
          ),
        const SizedBox(height: 20),
        _RideBar(progress: tracking.progress),
        const SizedBox(height: 12),
        Row(
          children: [
            if (placed != null)
              Expanded(
                child: Text(
                  'Placed ${formatOrderTime(context, placed)}',
                  style: small,
                ),
              ),
            if (arrives != null && tracking.status != 'cancelled')
              Expanded(
                child: Text(
                  'Arrives by ${formatOrderTime(context, arrives)}',
                  textAlign: TextAlign.end,
                  style: small,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RideBar extends StatelessWidget {
  const _RideBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const thumb = 40.0;
    return Semantics(
      label: 'Ride progress',
      value: '${(progress * 100).round()}%',
      child: SizedBox(
        height: thumb,
        child: LayoutBuilder(
          builder: (context, box) {
            final left = (box.maxWidth - thumb) * progress;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.colors.soft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: 12,
                  width: left + thumb / 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.orange, AppColors.yellow],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 600),
                  left: left,
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.orange, width: 2),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      size: 24,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kit 9.4-G: the food has arrived. Tapping a star starts the review with
/// the restaurant rated that many.
class OrderDeliveredScreen extends StatelessWidget {
  const OrderDeliveredScreen(this.order, {super.key});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final navigator = Navigator.of(context);
    void done() => navigator.popUntil((route) => route.isFirst);
    return OutcomePage(
      icon: Icons.check_rounded,
      title: 'Order delivered',
      message: 'Your order from ${order.restaurantName ?? 'the restaurant'} '
          'has arrived. Enjoy it!',
      button: 'Done',
      onButton: done,
      extra: order.reviewed
          ? null
          : Column(
              children: [
                Text(
                  'Rate your order',
                  style: TextStyle(fontSize: 18, color: colors.onHeader),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 1; s <= 5; s++)
                      IconButton(
                        tooltip: '$s star${s == 1 ? '' : 's'}',
                        onPressed: () async {
                          final sent = await openReview(
                            context,
                            order,
                            restaurantRating: s,
                          );
                          if (sent) done();
                        },
                        icon: const Icon(Icons.star_outline_rounded),
                        color: AppColors.orange,
                        iconSize: 36,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
