import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/search_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/widgets/app_bottom_nav.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/catalog_rows.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/radius_map.dart';

/// The signed-in shell: Home (1.15) plus the other tabs, which arrive in
/// later phases.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: const [
          _NearbyTab(),
          // Log Out moves to the profile menu in redesign step 3.
          _ComingSoon(title: 'Menu', when: 'redesign step 3', showLogout: true),
          _ComingSoon(title: 'Favorites', when: 'phase 8'),
          _ComingSoon(title: 'My orders', when: 'phase 6'),
          _ComingSoon(title: 'Help', when: 'phase 7'),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// 1.15: the ring map with a sheet listing what is inside the ring.
class _NearbyTab extends StatefulWidget {
  const _NearbyTab();

  @override
  State<_NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<_NearbyTab> {
  final _catalog = CatalogService();

  Here? _here;
  List<Restaurant> _restaurants = const [];
  List<MenuItem> _dishes = const [];
  bool _loading = true;
  String? _error;

  double _km = 5;
  bool _showDishes = false;
  String? _category;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// One request for each list; radius and food filters then run on the
  /// phone, so dragging the ring never waits on the network.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final here = await LocationService().here();
      final results = await Future.wait([
        // Only what the ring can reach; further away can't be delivered.
        _catalog.restaurants(
          lat: here.lat,
          lng: here.lng,
          maxKm: RadiusMap.maxKm,
        ),
        _catalog.menuItems(
          lat: here.lat,
          lng: here.lng,
          maxKm: RadiusMap.maxKm,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _here = here;
        _restaurants = results[0] as List<Restaurant>;
        _dishes = results[1] as List<MenuItem>;
      });
    } on SessionExpiredException {
      await AuthService().logout();
      if (!mounted) return;
      await Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
      return;
    } on Exception catch (e) {
      debugPrint('[Home] load failed: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Restaurant r) =>
      _category == null || r.categories.contains(_category);

  bool _within(double? km) => (km ?? double.infinity) <= _km;

  List<Restaurant> get _places => [
        for (final r in _restaurants)
          if (_within(r.distanceKm) && _matches(r)) r,
      ];

  List<MenuItem> get _dishesInside => [
        for (final m in _dishes)
          if (_within(m.distanceKm) &&
              (_category == null || m.category == _category))
            m,
      ];

  /// The nearest restaurant outside the ring that passes the food filter.
  Restaurant? get _nearestOutside {
    for (final r in _restaurants) {
      if (!_within(r.distanceKm) && _matches(r)) return r;
    }
    return null;
  }

  void _openSearch() {
    final here = _here;
    if (here == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.search,
      arguments: SearchArgs(
        lat: here.lat,
        lng: here.lng,
        km: _km,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final here = _here;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final mapHeight = height * 0.55;
        // The sheet starts 30 px up over the map, under its rounded corners.
        final sheetStart = (height - mapHeight + 30) / height;

        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mapHeight + 30,
              child: here == null
                  ? const SizedBox.shrink()
                  : RadiusMap(
                      lat: here.lat,
                      lng: here.lng,
                      restaurants: _restaurants,
                      km: _km,
                      onKmChanged: (km) => setState(() => _km = km),
                      matches: _matches,
                      topInset: top + 56,
                      bottomInset: 30,
                    ),
            ),
            Positioned(
              top: top + 8,
              left: 25,
              right: 25,
              child: Row(
                children: [
                  // Flexible: without it the Row gives the pill unlimited
                  // width, and a long area name ran off the screen.
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _AreaPill(
                        here: here,
                        loading: _loading,
                        onTap: _loading ? null : _load,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _BellButton(),
                ],
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: sheetStart,
              minChildSize: sheetStart,
              maxChildSize: 0.92,
              snap: true,
              builder: (context, scroll) => _sheet(scroll),
            ),
          ],
        );
      },
    );
  }

  Widget _sheet(ScrollController scroll) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom + 110;

    final List<Widget> rows;
    if (_loading && _here == null) {
      rows = const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.greenDark),
          ),
        ),
      ];
    } else if (_error != null && _here == null) {
      rows = [_LoadError(message: _error!, onRetry: _load)];
    } else if (_showDishes) {
      final dishes = _dishesInside;
      rows = dishes.isEmpty
          ? [_nothingInside()]
          : [for (final m in dishes) DishRow(item: m)];
    } else {
      final places = _places;
      rows = places.isEmpty
          ? [_nothingInside()]
          : [for (final r in places) PlaceRow(restaurant: r)];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1A5A6CEA),
                  blurRadius: 40,
                  offset: Offset(0, -10),
                ),
              ],
      ),
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 10, 25, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.backButton,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _header(),
                  const SizedBox(height: 14),
                  _chips(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(25, 0, 25, bottom),
            sliver: SliverList.separated(
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i],
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final colors = context.colors;
    final here = _here;
    final km = formatKm(_km);
    final String title;
    final String subtitle;
    if (here == null) {
      title = 'Finding places near you';
      subtitle = 'Using your location';
    } else if (_showDishes) {
      final n = _dishesInside.length;
      title = '$n ${n == 1 ? 'dish' : 'dishes'} within $km';
      subtitle = 'Most ordered first';
    } else {
      final places = _places;
      final n = places.length;
      title = '$n ${n == 1 ? 'place' : 'places'} within $km';
      final mins = [
        for (final r in places)
          if (r.deliveryTimeMins != null) r.deliveryTimeMins!,
      ];
      subtitle = mins.isEmpty
          ? 'Drag the ring out to reach more'
          : 'Delivery in ${mins.reduce(math.min)}–${mins.reduce(math.max)} min, nearest first';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                here != null && !here.fromGps
                    ? 'Near your saved address. Turn on location for where you are now.'
                    : subtitle,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Search',
          excludeSemantics: true,
          child: InkWell(
            onTap: here == null ? null : _openSearch,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.searchField,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.orange,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chips() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          ChoicePill(
            label: 'Places',
            accent: true,
            selected: !_showDishes,
            onTap: () => setState(() => _showDishes = false),
          ),
          const SizedBox(width: 8),
          ChoicePill(
            label: 'Dishes',
            accent: true,
            selected: _showDishes,
            onTap: () => setState(() => _showDishes = true),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: AppColors.orange.withValues(alpha: 0.25),
          ),
          ChoicePill(
            label: 'All',
            selected: _category == null,
            onTap: () => setState(() => _category = null),
          ),
          for (final entry in foodCategories.entries) ...[
            const SizedBox(width: 8),
            ChoicePill(
              label: entry.value,
              selected: _category == entry.key,
              onTap: () => setState(() => _category = entry.key),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nothingInside() {
    final nearest = _nearestOutside;
    final colors = context.colors;
    // Nothing within the ring's limit at all: no delivery here yet.
    if (_restaurants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Text(
          "YumQuick doesn't deliver here yet: no restaurants within "
          '${formatKm(RadiusMap.maxKm)} of you.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: colors.textSecondary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nearest == null
                ? 'Nothing nearby serves that yet.'
                : 'Nothing here within ${formatKm(_km)}. The nearest is '
                    '${nearest.name}, ${formatKm(nearest.distanceKm!)} away.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
          if (nearest != null) ...[
            const SizedBox(height: 12),
            MajorButton(
              horizontal: 20,
              vertical: 12,
              textonButton: 'Widen to ${formatKm(_kmToInclude(nearest))}',
              onPress: () => setState(() => _km = _kmToInclude(nearest)),
            ),
          ],
        ],
      ),
    );
  }

  /// The smallest half-km step that reaches [r].
  double _kmToInclude(Restaurant r) =>
      ((r.distanceKm! * 2).ceil() / 2).clamp(RadiusMap.minKm, RadiusMap.maxKm);
}

class _AreaPill extends StatelessWidget {
  const _AreaPill({
    required this.here,
    required this.loading,
    required this.onTap,
  });

  final Here? here;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final place = here;
    final label = place == null
        ? 'Finding you…'
        : place.area.isEmpty
            ? 'Near you'
            : place.area;
    return Semantics(
      button: true,
      label: 'Location: $label. Tap to refresh.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 40,
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                place == null || place.fromGps
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                size: 18,
                color: AppColors.greenDark,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 8),
                const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.greenDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Notifications',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.greenDark,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// The bell's destination until the notifications screen (1.30) is built in
/// phase 8.
class NotificationsPlaceholder extends StatelessWidget {
  const NotificationsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 25,
              child: CustomBackButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const _ComingSoon(title: 'Notifications', when: 'phase 8'),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: AppColors.greenDark.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          MajorButton(
            horizontal: 40,
            vertical: 14,
            textonButton: 'Try Again',
            onPress: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Tabs whose screens come in later phases.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.title,
    required this.when,
    this.showLogout = false,
  });

  final String title;

  /// "phase 6", "redesign step 3".
  final String when;
  final bool showLogout;

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Log Out',
        message: 'Are you sure you want to log out?',
        primaryLabel: 'Log Out',
        primaryIsDestructive: true,
        secondaryLabel: 'Cancel',
        onPrimary: () => Navigator.of(ctx).pop(true),
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    await AuthService().logout();
    if (!context.mounted) return;
    nav.pop(); // dismiss overlay
    await nav.pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Coming in $when',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            if (showLogout) ...[
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => _logout(context),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
