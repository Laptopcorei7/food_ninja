import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// 7-A: a dish with its photo, price, quantity, portions and Add to Cart.
/// Shows [item] from the list straight away and loads the portions and
/// the saved heart on top.
class DishScreen extends StatefulWidget {
  const DishScreen({required this.item, this.here, super.key});

  final MenuItem item;
  final Here? here;

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  final _catalog = CatalogService();
  late MenuItem _dish = widget.item;
  bool _loaded = false;
  String? _error;
  int _qty = 1;
  DishOption? _option;
  bool _saved = false;
  bool _adding = false;

  static const _maxQty = 99;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final dish = await _catalog.dish(
        widget.item.id,
        lat: widget.here?.lat,
        lng: widget.here?.lng,
      );
      if (!mounted) return;
      setState(() {
        _dish = dish;
        _loaded = true;
        _option = dish.options.firstOrNull;
        _saved = dish.isFavorite;
      });
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Dish] load failed: $e');
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(Exception e) => e.toString().replaceFirst('Exception: ', '');

  double get _unitPrice => _dish.price + (_option?.extraPrice ?? 0);

  // The list's copy names the restaurant when the dish's own may not.
  String? get _restaurantName =>
      _dish.restaurantName ?? widget.item.restaurantName;

  Future<void> _toggleSaved() async {
    final want = !_saved;
    setState(() => _saved = want);
    try {
      await _catalog.setFavorite(_dish.id, saved: want);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Dish] favourite failed: $e');
      if (!mounted) return;
      setState(() => _saved = !want);
      _snack(_message(e));
    }
  }

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      await _catalog.addToCart(_dish.id, _qty, optionId: _option?.id);
      if (!mounted) return;
      // The snackbar outlives this page: taken now, the navigator still
      // works if the user goes back before tapping View cart.
      final navigator = Navigator.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const ImageIcon(
                  AppIcons.checkCircle,
                  size: 22,
                  color: AppColors.yellow,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Added $_qty × ${_dish.name} to your cart'),
                ),
              ],
            ),
            // With an action Flutter keeps a snackbar until it is tapped.
            persist: false,
            action: SnackBarAction(
              label: 'View cart',
              onPressed: () => navigator.pushNamed(AppRoutes.cart),
            ),
          ),
        );
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Dish] add to cart failed: $e');
      if (mounted) _snack(_message(e));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _openRestaurant() {
    final id = _dish.restaurantId;
    if (id == null) return;
    Navigator.of(context)
        .pushNamed(AppRoutes.restaurant, arguments: (id, widget.here));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return SheetScaffold(
      headerHeight: 112,
      header: Row(
        children: [
          const SizedBox(width: 8),
          CustomBackButton(onTap: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _dish.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: 22,
                      height: 1.1,
                      color: colors.onHeader,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                RatingBadge(_dish.rating),
              ],
            ),
          ),
          _HeartButton(
            saved: _saved,
            onTap: _loaded ? _toggleSaved : null,
          ),
          const SizedBox(width: 12),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: FoodPhoto(url: _dish.photoUrl, semanticLabel: _dish.name),
            ),
          ),
          if (_restaurantName case final name?) ...[
            const SizedBox(height: 4),
            _RestaurantLink(
              name: name,
              distanceKm: _dish.distanceKm ?? widget.item.distanceKm,
              onTap: _openRestaurant,
            ),
          ] else
            const SizedBox(height: 12),
          Divider(color: colors.divider),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatCedis(_unitPrice),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: colors.accentText,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: 'One less',
                onTap: _qty > 1 ? () => setState(() => _qty--) : null,
              ),
              Semantics(
                liveRegion: true,
                label: 'Quantity $_qty',
                excludeSemantics: true,
                child: SizedBox(
                  width: 44,
                  child: Text(
                    '$_qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: 'One more',
                onTap: _qty < _maxQty ? () => setState(() => _qty++) : null,
              ),
            ],
          ),
          Divider(color: colors.divider),
          if (_dish.description case final description?
              when description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description, style: textTheme.bodyLarge),
          ],
          if (_dish.ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _Heading('Ingredients'),
            Text(_dish.ingredients.join(', '), style: textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          if (_error != null)
            _LoadError(message: _error!, onRetry: _load)
          else if (!_loaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_dish.options.isNotEmpty) ...[
            const _Heading('Portion'),
            RadioGroup<String>(
              groupValue: _option?.id,
              onChanged: (id) => setState(
                () => _option = _dish.options.firstWhere((o) => o.id == id),
              ),
              child: Column(
                children: [
                  for (final option in _dish.options)
                    _OptionRow(
                      option: option,
                      onTap: () => setState(() => _option = option),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: MajorButton(
              horizontal: 32,
              vertical: 12,
              textonButton: _adding
                  ? 'Adding…'
                  : 'Add to Cart · ${formatCedis(_unitPrice * _qty)}',
              // Wait for the portions so the right one goes in the cart.
              onPress: _loaded && !_adding ? _addToCart : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The kit's orange round heart at the right of the title.
class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: saved ? 'Remove from favourites' : 'Add to favourites',
      isSelected: saved,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        // White on the brand orange reads in both modes.
        child: saved
            ? const Icon(Icons.favorite_rounded, size: 20, color: Colors.white)
            : const ImageIcon(AppIcons.heart, size: 18, color: Colors.white),
      ),
    );
  }
}

/// "from Tasty Bites · 1.2 km", opening the restaurant's page.
class _RestaurantLink extends StatelessWidget {
  const _RestaurantLink({
    required this.name,
    required this.distanceKm,
    required this.onTap,
  });

  final String name;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = [
      'from $name',
      if (distanceKm != null) formatKm(distanceKm!),
    ].join(' · ');
    return Semantics(
      button: true,
      label: '$text. Open the restaurant',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              ImageIcon(AppIcons.utensils, size: 16, color: colors.accentText),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.accentText,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.accentText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The kit's orange round − / + buttons.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 44, height: 48),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.orange.withValues(alpha: 0.4)
              : AppColors.orange,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                color: context.colors.textPrimary,
              ),
        ),
      ),
    );
  }
}

/// "Large ······· + GH₵ 10 (o)", the whole row selecting the portion.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.onTap});

  final DishOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextStyle(fontSize: 16, color: colors.textBody);
    final price = option.extraPrice == 0
        ? 'Included'
        : '+ ${formatCedis(option.extraPrice)}';
    // Name and price sit on page-coloured patches over a dotted line, so
    // the dots fill exactly the gap between them.
    Widget patch(Widget child, EdgeInsets padding) => ColoredBox(
          color: colors.background,
          child: Padding(padding: padding, child: child),
        );
    // One screen-reader item: name, price and the radio's state.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _Dots(colors.divider)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: patch(
                            Text(
                              option.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            ),
                            const EdgeInsets.only(right: 8),
                          ),
                        ),
                      ),
                      patch(
                        Text(price, style: style),
                        const EdgeInsets.only(left: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Radio<String>(value: option.id, activeColor: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

class _Dots extends CustomPainter {
  const _Dots(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = size.height / 2 + 4;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawCircle(Offset(x, y), 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
