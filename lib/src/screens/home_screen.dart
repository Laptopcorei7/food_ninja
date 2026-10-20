import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/dish_list_screen.dart';
import 'package:food_ninja/src/screens/menu_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/app_bottom_nav.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/category_strip.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';
import 'package:food_ninja/src/widgets/shop_header.dart';

/// The signed-in shell: five tabs, the profile drawer, and the user's
/// location shared by the tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0;
  MenuFilter _filter = const MenuFilter();

  Here? _here;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_locate());
  }

  Future<void> _locate() async {
    setState(() => _error = null);
    try {
      final here = await LocationService().here();
      if (mounted) setState(() => _here = here);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Home] location failed: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showMenu(MenuFilter filter) => setState(() {
        _filter = filter;
        _tab = 1;
      });

  late final _actions = ShopActions(
    search: () {
      final here = _here;
      if (here != null) {
        Navigator.of(context).pushNamed(AppRoutes.search, arguments: here);
      }
    },
    cart: () => Navigator.of(context)
        .pushNamed(AppRoutes.comingSoon, arguments: ('Cart', 'phase 5')),
    bell: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
    profile: () => _scaffold.currentState?.openEndDrawer(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffold,
      endDrawer: _ProfileDrawer(
        onTab: (tab) {
          Navigator.of(context).pop();
          setState(() => _tab = tab);
        },
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            here: _here,
            error: _error,
            onRetry: _locate,
            actions: _actions,
            onCategory: (c) => _showMenu(_filter.copyWith(category: () => c)),
          ),
          MenuTab(
            here: _here,
            error: _error,
            onRetry: _locate,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
          ),
          const ComingSoonTab(title: 'Favorites', when: 'phase 8'),
          const ComingSoonTab(title: 'My Orders', when: 'phase 6'),
          const ComingSoonTab(title: 'Help', when: 'phase 7'),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// What Home's header buttons do.
class ShopActions {
  const ShopActions({
    required this.search,
    required this.cart,
    required this.bell,
    required this.profile,
  });

  final VoidCallback search;
  final VoidCallback cart;
  final VoidCallback bell;
  final VoidCallback profile;

  Widget header() => ShopHeader(
        onSearch: search,
        onCart: cart,
        onBell: bell,
        onProfile: profile,
      );
}

/// Opens a restaurant's page; dish taps land there until the dish screen
/// (phase 4).
void openRestaurant(BuildContext context, String? id, Here? here) {
  if (id == null) return;
  Navigator.of(context).pushNamed(AppRoutes.restaurant, arguments: (id, here));
}

/// Home's greeting, by time of day.
(String, String) greetingFor(DateTime now) => switch (now.hour) {
      >= 5 && < 12 => ('Good Morning', "Rise and shine! It's breakfast time"),
      >= 12 && < 17 => ('Good Afternoon', 'Time for a proper lunch'),
      >= 17 && < 22 => ('Good Evening', "Supper's a few taps away"),
      _ => ('Still Up?', 'Late bites from places still open'),
    };

/// 3-A / 9.1: categories, picks for the user, best sellers, offers, places
/// near you and recommendations.
class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.here,
    required this.error,
    required this.onRetry,
    required this.actions,
    required this.onCategory,
  });

  final Here? here;
  final String? error;
  final VoidCallback onRetry;
  final ShopActions actions;
  final ValueChanged<String?> onCategory;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

typedef _HomeData = (
  List<MenuItem> forYou,
  List<MenuItem> popular,
  List<MenuItem> topRated,
  List<Restaurant> nearby,
  List<Voucher> offers,
);

class _HomeTabState extends State<_HomeTab> {
  final _catalog = CatalogService();
  Future<_HomeData>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.here != old.here) _load();
  }

  void _load() {
    final here = widget.here;
    if (here == null) return;
    setState(() {
      _data = _fetch(here);
    });
  }

  /// All the lists at once; throws the first failure as itself.
  Future<_HomeData> _fetch(Here here) async {
    // For You and offers are extras: without them Home still works.
    final forYou =
        _catalog.forYou(lat: here.lat, lng: here.lng).catchError((Object e) {
      debugPrint('[Home] for you failed: $e');
      return const <MenuItem>[];
    });
    final popular = _catalog.menuItems(lat: here.lat, lng: here.lng, limit: 10);
    final rated = _catalog.menuItems(
      lat: here.lat,
      lng: here.lng,
      filter: const MenuFilter(sort: 'rating'),
      limit: 6,
    )..ignore();
    final nearby = _catalog.restaurants(lat: here.lat, lng: here.lng, limit: 10)
      ..ignore();
    final offers = _catalog.vouchers().catchError((Object e) {
      debugPrint('[Home] offers failed: $e');
      return const <Voucher>[];
    });
    // The requests run together; .ignore() keeps a later one's failure from
    // being reported as unhandled when an earlier await throws first.
    return (
      await forYou,
      await popular,
      await rated,
      await nearby,
      await offers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (hello, line) = greetingFor(DateTime.now());
    final colors = context.colors;
    return SheetScaffold(
      headerHeight: 124,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.actions.header(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // One line each: the header has a fixed height, so a wrapped
            // greeting would overflow it on narrow phones or large text.
            child: Semantics(
              header: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  hello,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 30,
                        color: colors.onHeader,
                      ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.accentText,
              ),
            ),
          ),
        ],
      ),
      child: _body(),
    );
  }

  Widget _body() {
    final here = widget.here;
    if (here == null) {
      return widget.error == null
          ? const LoadingSpinner()
          : LoadError(message: widget.error!, onRetry: widget.onRetry);
    }
    return FutureBuilder<_HomeData>(
      future: _data,
      builder: (context, snap) {
        if (snap.error case final error?) {
          if (error is SessionExpiredException) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => signOutExpired(context));
          }
          debugPrint('[Home] load failed: $error');
          return LoadError(
            message: "Couldn't load what's near you. Check your connection.",
            onRetry: _load,
          );
        }
        final data = snap.data;
        if (data == null) return const LoadingSpinner();
        return RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () async {
            _load();
            await _data;
          },
          child: _content(data, here),
        );
      },
    );
  }

  Widget _content(_HomeData data, Here here) {
    final (forYou, popular, rated, nearby, offers) = data;
    // Until someone has orders, For You falls back to top-rated dishes, so
    // Recommend leaves out what For You already shows.
    final shown = {for (final m in forYou) m.id};
    final topRated = [
      for (final m in rated)
        if (!shown.contains(m.id)) m,
    ];
    final colors = context.colors;

    Widget strip(List<MenuItem> items) => SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Bounce at the ends: Android's stretch squashed the end cards.
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 124,
              child: DishTile(
                item: items[i],
                onTap: () =>
                    openRestaurant(context, items[i].restaurantId, here),
              ),
            ),
          ),
        );
    void dishes(String title, String intro, String sort) => Navigator.of(
          context,
        ).pushNamed(
          AppRoutes.dishes,
          arguments: DishListArgs(
            title: title,
            intro: intro,
            sort: sort,
            here: here,
          ),
        );

    if (popular.isEmpty && nearby.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          CategoryStrip(selected: null, onSelected: widget.onCategory),
          const SizedBox(height: 48),
          Text(
            'No restaurants deliver to ${here.area.isEmpty ? 'you' : here.area} '
            'yet. Pull down to check again later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 34, bottom: 32),
      children: [
        CategoryStrip(selected: null, onSelected: widget.onCategory),
        const Divider(indent: 24, endIndent: 24, height: 24),
        if (forYou.isNotEmpty) ...[
          const SectionHeader(title: 'For You'),
          strip(forYou),
          const SizedBox(height: 12),
        ],
        if (popular.isNotEmpty) ...[
          SectionHeader(
            title: 'Best Seller',
            onViewAll: () => dishes(
              'Best Seller',
              'The most ordered dishes near you',
              'popular',
            ),
          ),
          strip(popular),
        ],
        if (offers.isNotEmpty) ...[
          const SizedBox(height: 20),
          _OfferBanner(offers: offers),
        ],
        if (nearby.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Near You'),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // Bounce at the ends: Android's stretch squashed the end cards.
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: nearby.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: 180,
                child: RestaurantCard(
                  restaurant: nearby[i],
                  onTap: () => openRestaurant(context, nearby[i].id, here),
                ),
              ),
            ),
          ),
        ],
        if (topRated.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Recommend',
            onViewAll: () => dishes(
              'Recommendations',
              'The best rated dishes near you',
              'rating',
            ),
          ),
          DishGrid(items: topRated, here: here, shrinkWrap: true),
        ],
      ],
    );
  }
}

/// Two-column dish cards with ratings (3-A recommend, 6-A, 8-A).
class DishGrid extends StatelessWidget {
  const DishGrid({
    required this.items,
    required this.here,
    this.shrinkWrap = false,
    this.opensRestaurant = true,
    super.key,
  });

  final List<MenuItem> items;
  final Here? here;

  /// False on a restaurant's own page, where the dish screen (phase 4) is
  /// the only useful target.
  final bool opensRestaurant;

  /// True inside another scroll view.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        mainAxisExtent: 216,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => DishTile(
        item: items[i],
        photoHeight: 144,
        showRating: true,
        onTap: opensRestaurant
            ? () => openRestaurant(context, items[i].restaurantId, here)
            : null,
      ),
    );
  }
}

/// 3-A's offer banner: orange half with the deal, photo half, page dots.
class _OfferBanner extends StatefulWidget {
  const _OfferBanner({required this.offers});

  final List<Voucher> offers;

  @override
  State<_OfferBanner> createState() => _OfferBannerState();
}

class _OfferBannerState extends State<_OfferBanner> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.offers;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            itemCount: offers.length,
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _OfferCard(offer: offers[i]),
            ),
          ),
        ),
        if (offers.length > 1) ...[
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < offers.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          i == _page ? AppColors.orange : context.colors.field,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Voucher offer;

  @override
  Widget build(BuildContext context) {
    final amount = '${formatCedis(offer.discountAmount)} OFF';
    return Semantics(
      label: '${offer.title}. $amount. ${offer.description ?? ''}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          // Both halves fill the card's height, so the corners line up.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: AppColors.orange,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (offer.description case final d? when d.isNotEmpty)
                        Flexible(
                          child: Text(
                            d,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: FoodPhoto(url: offer.photoUrl)),
          ],
        ),
      ),
    );
  }
}

/// 4.1-A: the orange profile panel from the right.
class _ProfileDrawer extends StatefulWidget {
  const _ProfileDrawer({required this.onTab});

  /// Switches the shell to a tab (orders, help).
  final ValueChanged<int> onTab;

  @override
  State<_ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<_ProfileDrawer> {
  late final Future<Map<String, dynamic>> _me = UserService().getMe();

  void _soon(String title) {
    Navigator.of(context)
      ..pop()
      ..pushNamed(AppRoutes.comingSoon, arguments: (title, 'phase 8'));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: AppColors.orange,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(40)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _me,
              builder: (context, snap) => _Who(user: snap.data),
            ),
            const SizedBox(height: 24),
            _item(AppIcons.bag, 'My Orders', () => widget.onTab(3)),
            _item(AppIcons.user, 'My Profile', () => _soon('My Profile')),
            _item(
              AppIcons.location,
              'Delivery Address',
              () => _soon('Delivery Address'),
            ),
            _item(
              AppIcons.card,
              'Payment Methods',
              () => _soon('Payment Methods'),
            ),
            _item(AppIcons.phone, 'Contact Us', () => widget.onTab(4)),
            _item(AppIcons.chat, 'Help & FAQs', () => widget.onTab(4)),
            _item(AppIcons.settings, 'Settings', () => _soon('Settings')),
            const SizedBox(height: 16),
            _item(
              AppIcons.logOut,
              'Log Out',
              () => confirmLogOut(context),
              divider: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    AssetImage icon,
    String label,
    VoidCallback onTap, {
    bool divider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: ImageIcon(icon, size: 24, color: AppColors.orange),
                ),
                const SizedBox(width: 20),
                // Bold so white on orange reads as large text (3:1).
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (divider)
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.5),
            indent: 64,
          ),
      ],
    );
  }
}

class _Who extends StatelessWidget {
  const _Who({required this.user});

  final Map<String, dynamic>? user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = [u?['firstName'], u?['lastName']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');
    final photo = u?['photo'];
    return Row(
      children: [
        ClipOval(
          child: SizedBox.square(
            dimension: 56,
            child: photo is String && photo.isNotEmpty
                ? FoodPhoto(
                    url: photo,
                    semanticLabel: 'Your photo',
                    fallbackIcon: AppIcons.user,
                  )
                : const ColoredBox(
                    color: Colors.white,
                    child: ImageIcon(AppIcons.user, color: AppColors.orange),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? (u?['name'] as String? ?? '') : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                u?['email'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tab whose screens come in a later phase.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({required this.title, required this.when, super.key});

  final String title;

  /// "phase 6".
  final String when;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: title,
      showBack: false,
      child: _soonBody(context, when),
    );
  }
}

/// A screen that arrives in a later phase (cart, notifications, settings).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({required this.title, required this.when, super.key});

  final String title;
  final String when;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(title: title, child: _soonBody(context, when));
  }
}

Widget _soonBody(BuildContext context, String when) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Coming in $when.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: context.colors.textSecondary),
        ),
      ),
    );

/// The orange spinner used while a list loads.
class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
}

/// A load failure with a retry button.
class LoadError extends StatelessWidget {
  const LoadError({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 16, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
