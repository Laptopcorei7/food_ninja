import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// Home's ring map (1.15): the user in the centre, restaurants as photo
/// bubbles at their real direction and distance, and a ring for how far the
/// user will order from. Dragging anywhere on the map moves the ring's edge
/// to the finger; screen readers get it as a slider.
class RadiusMap extends StatelessWidget {
  const RadiusMap({
    required this.lat,
    required this.lng,
    required this.restaurants,
    required this.km,
    required this.onKmChanged,
    required this.matches,
    this.topInset = 0,
    this.bottomInset = 0,
    super.key,
  });

  final double lat;
  final double lng;
  final List<Restaurant> restaurants;
  final double km;
  final ValueChanged<double> onKmChanged;

  /// Whether a restaurant passes the food filter; the rest are dimmed.
  final bool Function(Restaurant) matches;

  /// Space at the top taken by the header, kept clear of the rings.
  final double topInset;

  /// Space at the bottom covered by something else (Home's sheet).
  final double bottomInset;

  static const minKm = 1.0;
  static const maxKm = 12.0;
  static const guideKms = [2.0, 5.0, 10.0];

  /// More bubbles than this crowd the centre; the list still shows them all.
  static const maxBubbles = 20;

  static const _bubble = 44.0;

  /// Radius on screen for a distance. The square root spreads out the first
  /// few km, where most restaurants are.
  static double _radius(double km, double rMax) =>
      rMax * math.sqrt(math.min(km, maxKm) / maxKm);

  static double _kmFor(double r, double rMax) {
    final km = maxKm * math.pow(math.min(r, rMax) / rMax, 2);
    return ((km * 2).round() / 2).clamp(minKm, maxKm);
  }

  void _set(double next) {
    if (next == km) return;
    unawaited(HapticFeedback.selectionClick());
    onKmChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final guide = dark
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.orange.withValues(alpha: 0.25);
    final guideText = dark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.orange.withValues(alpha: 0.7);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final free = size.height - topInset - bottomInset;
        final center = Offset(size.width / 2, topInset + free / 2);
        final rMax = math.min(size.width / 2, free / 2) - _bubble / 2 - 4;
        final ring = _radius(km, rMax);

        void follow(Offset local) =>
            _set(_kmFor((local - center).distance, rMax));

        final nearest = restaurants.take(maxBubbles).toList();
        final positions = _positions(nearest, center, rMax);
        const handleAngle = -28 * math.pi / 180;
        final handle = center +
            Offset(math.cos(handleAngle), math.sin(handleAngle)) * ring;

        return Semantics(
          slider: true,
          label: 'Delivery radius',
          value: formatKm(km),
          increasedValue: formatKm(math.min(km + 0.5, maxKm)),
          decreasedValue: formatKm(math.max(km - 0.5, minKm)),
          onIncrease: () => _set(math.min(km + 0.5, maxKm)),
          onDecrease: () => _set(math.max(km - 0.5, minKm)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => follow(d.localPosition),
            onPanUpdate: (d) => follow(d.localPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: dark ? 0.2 : 0.5,
                    child: Image.asset(
                      'assets/images/pattern.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RingsPainter(
                      center: center,
                      guides: [
                        for (final g in guideKms)
                          (_radius(g, rMax), formatKm(g)),
                      ],
                      ring: ring,
                      guideColor: guide,
                      labelColor: guideText,
                    ),
                  ),
                ),
                for (var i = 0; i < nearest.length; i++)
                  _placeBubble(
                    nearest[i],
                    positions[i],
                    inside: (nearest[i].distanceKm ?? 0) <= km,
                  ),
                Positioned(
                  left: center.dx - 22,
                  top: center.dy - 22,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.green.withValues(alpha: 0.3),
                      ),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.brandGradient,
                          border: Border.all(
                            color: context.colors.background,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: handle.dx,
                  top: handle.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: ExcludeSemantics(child: _Handle(km: km)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Where each restaurant's bubble goes. Places whose points land on the
  /// same spot (several share a neighbourhood centre in the seed data) are
  /// fanned out around it so every photo shows.
  List<Offset> _positions(
    List<Restaurant> places,
    Offset center,
    double rMax,
  ) {
    final raw = [
      for (final r in places)
        center + _direction(r) * _radius(r.distanceKm ?? 0, rMax),
    ];
    final groups = <List<int>>[];
    for (var i = 0; i < raw.length; i++) {
      final group = groups
          .where((g) => (raw[g.first] - raw[i]).distance < _bubble * 0.6)
          .firstOrNull;
      if (group == null) {
        groups.add([i]);
      } else {
        group.add(i);
      }
    }
    final out = [...raw];
    for (final group in groups.where((g) => g.length > 1)) {
      const spread = _bubble * 0.6;
      for (var k = 0; k < group.length; k++) {
        final angle = -math.pi / 2 + k * 2 * math.pi / group.length;
        out[group[k]] = raw[group.first] +
            Offset(math.cos(angle), math.sin(angle)) * spread;
      }
    }
    return out;
  }

  /// Unit vector from the user towards [r], screen up = north.
  Offset _direction(Restaurant r) {
    final rLat = r.lat;
    final rLng = r.lng;
    if (rLat == null || rLng == null) return Offset.zero;
    // Flat-earth offsets in km; fine at city scale.
    final dx = (rLng - lng) * 111.32 * math.cos(lat * math.pi / 180);
    final dy = (rLat - lat) * 110.57;
    final length = math.sqrt(dx * dx + dy * dy);
    return length > 0 ? Offset(dx, -dy) / length : Offset.zero;
  }

  Widget _placeBubble(
    Restaurant r,
    Offset pos, {
    required bool inside,
  }) {
    final lit = inside && matches(r);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: pos.dx - _bubble / 2,
      top: pos.dy - _bubble / 2,
      child: ExcludeSemantics(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 250),
          scale: lit ? 1 : 0.8,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: lit ? 1 : (inside ? 0.35 : 0.3),
            child: Container(
              width: _bubble,
              height: _bubble,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: lit
                    ? const [
                        BoxShadow(
                          color: Color(0x4009051C),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: ColorFiltered(
                  colorFilter: inside ? _none : _greyscale,
                  child: RestaurantPhoto(url: r.photoUrl),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _none = ColorFilter.mode(Colors.transparent, BlendMode.dst);
  static const _greyscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// A food photo that falls back to a green tile when missing or broken.
///
/// The photos are 800 px wide but shown at 44-56 px. Decoded at full size,
/// Home's ~60 photos overflowed Flutter's 100 MB image cache, so leaving a
/// screen and coming back downloaded them again. Decoding at twice the shown
/// width (enough for BoxFit.cover on a landscape photo) keeps them cached.
class RestaurantPhoto extends StatelessWidget {
  const RestaurantPhoto({required this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.green.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.restaurant, color: AppColors.greenDark, size: 20),
      ),
    );
    final src = url;
    if (src == null || src.isEmpty) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        src,
        fit: BoxFit.cover,
        cacheWidth: constraints.hasBoundedWidth
            ? (constraints.maxWidth * dpr * 2).round()
            : null,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[RestaurantPhoto] $src failed: $error');
          return fallback;
        },
        frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4015BE77),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.unfold_more, size: 16, color: AppColors.greenDark),
          const SizedBox(width: 4),
          Text(
            formatKm(km),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.center,
    required this.guides,
    required this.ring,
    required this.guideColor,
    required this.labelColor,
  });

  final Offset center;
  final List<(double, String)> guides;
  final double ring;
  final Color guideColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (radius, label) in guides) {
      // Dashes of about 4 px with 4 px gaps.
      final steps = math.max(12, (2 * math.pi * radius / 8).floor());
      final sweep = 2 * math.pi / steps;
      final rect = Rect.fromCircle(center: center, radius: radius);
      for (var i = 0; i < steps; i++) {
        canvas.drawArc(rect, i * sweep, sweep / 2, false, dash);
      }
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'BentonSans',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        center + Offset(-text.width / 2, radius - text.height - 4),
      );
    }

    canvas
      ..drawCircle(
        center,
        ring,
        Paint()..color = AppColors.green.withValues(alpha: 0.12),
      )
      ..drawCircle(
        center,
        ring,
        Paint()
          ..color = AppColors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.ring != ring ||
      old.center != center ||
      old.guideColor != guideColor ||
      old.guides.length != guides.length;
}
