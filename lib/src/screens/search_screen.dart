import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/widgets/catalog_rows.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/radius_map.dart';

/// Where the search starts: the user's position and Home's filters.
@immutable
class SearchArgs {
  const SearchArgs({
    required this.lat,
    required this.lng,
    required this.km,
    this.category,
  });

  final double lat;
  final double lng;
  final double km;
  final String? category;
}

/// 1.16 search results and 1.17 nothing nearby / offline. Matches come from
/// up to [RadiusMap.maxKm] away (further can't be delivered); those inside
/// the user's ring are listed and the rest are counted, so the user can
/// widen the ring instead of retyping.
class SearchScreen extends StatefulWidget {
  const SearchScreen({required this.args, super.key});

  final SearchArgs args;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _catalog = CatalogService();
  Timer? _debounce;

  /// Null means anywhere up to [RadiusMap.maxKm].
  late double? _km = widget.args.km;
  late String? _category = widget.args.category;
  bool _showDishes = false;

  String _query = '';
  List<Restaurant> _restaurants = const [];
  List<MenuItem> _dishes = const [];
  bool _loading = false;
  String? _error;

  /// Drops answers to older queries that arrive after newer ones.
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(text));
  }

  Future<void> _run(String text) async {
    final query = text.trim();
    final request = ++_request;
    setState(() {
      _query = query;
      _error = null;
      _loading = query.isNotEmpty;
    });
    if (query.isEmpty) return;

    final a = widget.args;
    try {
      final results = await Future.wait([
        // Nothing past the ring's limit: it can't be delivered.
        _catalog.restaurants(
          lat: a.lat,
          lng: a.lng,
          search: query,
          maxKm: RadiusMap.maxKm,
        ),
        _catalog.menuItems(
          lat: a.lat,
          lng: a.lng,
          search: query,
          maxKm: RadiusMap.maxKm,
          sort: 'distance',
        ),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _restaurants = results[0] as List<Restaurant>;
        _dishes = results[1] as List<MenuItem>;
      });
    } on SessionExpiredException {
      await AuthService().logout();
      if (!mounted) return;
      await Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
    } on Exception catch (e) {
      debugPrint('[Search] "$query" failed: $e');
      if (mounted && request == _request) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  bool _within(double? km) => _km == null || (km ?? double.infinity) <= _km!;

  bool _placeMatches(Restaurant r) =>
      _category == null || r.categories.contains(_category);

  bool _dishMatches(MenuItem m) => _category == null || m.category == _category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 16, 25, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 9),
                  Expanded(child: _field(colors)),
                ],
              ),
              const SizedBox(height: 18),
              _chips(),
              const SizedBox(height: 18),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(AppColors colors) {
    return TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      onSubmitted: (text) {
        _debounce?.cancel();
        unawaited(_run(text));
      },
      style: TextStyle(fontSize: 14, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Jollof, waakye, a restaurant…',
        hintStyle: TextStyle(fontSize: 13, color: colors.hint),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.orange),
        fillColor: colors.searchField,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        // The theme's outlined box would draw around the cream fill.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.green),
        ),
      ),
    );
  }

  Widget _chips() {
    final km = _km;
    final category = _category;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoicePill(
          label: 'Places',
          accent: true,
          selected: !_showDishes,
          onTap: () => setState(() => _showDishes = false),
        ),
        ChoicePill(
          label: 'Dishes',
          accent: true,
          selected: _showDishes,
          onTap: () => setState(() => _showDishes = true),
        ),
        if (km != null)
          _RemovableChip(
            label: 'Within ${formatKm(km)}',
            onRemove: () => setState(() => _km = null),
          ),
        if (category != null)
          _RemovableChip(
            label: foodCategories[category] ?? category,
            onRemove: () => setState(() => _category = null),
          ),
      ],
    );
  }

  Widget _body() {
    final colors = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom + 24;

    if (_query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Search dishes and restaurants within '
          '${formatKm(_km ?? RadiusMap.maxKm)} of you.',
          style:
              TextStyle(fontSize: 14, height: 1.5, color: colors.textSecondary),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.greenDark),
      );
    }
    final error = _error;
    if (error != null) {
      final offline = error.contains('internet');
      return _Message(
        icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
        title: offline ? "You're offline" : 'Something went wrong',
        body: error,
        action: 'Try Again',
        onAction: () => _run(_query),
      );
    }

    final List<Widget> inside;
    final int outside;
    double? nearestKm;
    String? nearestName;
    if (_showDishes) {
      final all = _dishes.where(_dishMatches).toList();
      final hits = all.where((m) => _within(m.distanceKm)).toList();
      final rest = all.where((m) => !_within(m.distanceKm)).toList();
      inside = [for (final m in hits) DishRow(item: m)];
      outside = rest.length;
      if (rest.isNotEmpty) {
        nearestKm = rest.first.distanceKm;
        nearestName = '${rest.first.name} at ${rest.first.restaurantName}';
      }
    } else {
      final all = _restaurants.where(_placeMatches).toList();
      final hits = all.where((r) => _within(r.distanceKm)).toList();
      final rest = all.where((r) => !_within(r.distanceKm)).toList();
      inside = [for (final r in hits) PlaceRow(restaurant: r)];
      outside = rest.length;
      if (rest.isNotEmpty) {
        nearestKm = rest.first.distanceKm;
        nearestName = rest.first.name;
      }
    }

    if (inside.isEmpty) {
      if (nearestKm != null && _km != null) {
        final widen = math.min((nearestKm * 2).ceil() / 2, RadiusMap.maxKm);
        return _Message(
          ring: true,
          title: 'No "$_query" within ${formatKm(_km!)}',
          body: 'The nearest is $nearestName, ${formatKm(nearestKm)} away.',
          action: 'Widen to ${formatKm(widen)}',
          onAction: () => setState(() => _km = widen),
        );
      }
      return _Message(
        icon: Icons.search_off_rounded,
        title: 'Nothing called "$_query" nearby',
        body: 'Nothing within ${formatKm(RadiusMap.maxKm)} of you matches. '
            'Try another word, or check the spelling.',
        action: 'Clear Search',
        onAction: () {
          _controller.clear();
          unawaited(_run(''));
        },
      );
    }

    final noun = _showDishes
        ? (inside.length == 1 ? 'dish' : 'dishes')
        : (inside.length == 1 ? 'place' : 'places');
    return ListView(
      padding: EdgeInsets.only(bottom: bottom),
      children: [
        Text(
          '${inside.length} $noun'
          '${_km == null ? '' : ' within ${formatKm(_km!)}'}, nearest first',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final row in inside) ...[row, const SizedBox(height: 12)],
        if (outside > 0)
          _WidenRow(count: outside, onTap: () => setState(() => _km = null)),
      ],
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColors.green : const Color(0xFF0E8A55);
    return Semantics(
      button: true,
      label: 'Remove filter $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 34,
          padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.close_rounded, size: 15, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidenRow extends StatelessWidget {
  const _WidenRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.radar_rounded, color: AppColors.orange),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count more further out',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Show them all',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

/// Centred message with one action: nothing nearby, no results, offline.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.icon,
    this.ring = false,
  });

  final IconData? icon;

  /// Draws the radius rings instead of an icon.
  final bool ring;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final guide = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.orange.withValues(alpha: 0.3);
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          if (ring)
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final size in [180.0, 110.0])
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: guide),
                        ),
                      ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.green.withValues(alpha: 0.14),
                        border: Border.all(color: AppColors.green, width: 1.5),
                      ),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.brandGradient,
                      ),
                    ),
                    const Positioned(
                      right: 22,
                      top: 34,
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 48, color: AppColors.greenDark),
            ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: MajorButton(
              horizontal: 20,
              vertical: 18,
              textonButton: action,
              onPress: onAction,
            ),
          ),
        ],
      ),
    );
  }
}
