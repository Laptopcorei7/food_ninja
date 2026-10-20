import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// A restaurant's page (not in the kit; built in its style): photo, facts,
/// then its menu by category.
class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({required this.id, this.here, super.key});

  final String id;

  /// For the distance; null leaves it out.
  final Here? here;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _catalog = CatalogService();
  late Future<(Restaurant, List<MenuItem>)> _data = _fetch();

  /// Both at once; `.ignore()` keeps the menu's failure from being reported
  /// as unhandled when the restaurant request fails first.
  Future<(Restaurant, List<MenuItem>)> _fetch() async {
    final restaurant = _catalog.restaurant(
      widget.id,
      lat: widget.here?.lat,
      lng: widget.here?.lng,
    );
    final menu = _catalog.restaurantMenu(widget.id)..ignore();
    return (await restaurant, await menu);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Restaurant, List<MenuItem>)>(
      future: _data,
      builder: (context, snap) {
        final restaurant = snap.data?.$1;
        return SheetScaffold(
          title: restaurant?.name ?? '',
          child: _body(snap),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<(Restaurant, List<MenuItem>)> snap) {
    if (snap.error case final error?) {
      if (error is SessionExpiredException) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => signOutExpired(context));
      }
      debugPrint('[Restaurant] load failed: $error');
      return LoadError(
        message: "Couldn't load this restaurant. Check your connection.",
        onRetry: () => setState(() {
          _data = _fetch();
        }),
      );
    }
    final data = snap.data;
    if (data == null) return const LoadingSpinner();
    final (r, menu) = data;
    final colors = context.colors;

    // Menu grouped by category, in the order the categories are listed.
    final groups = <String, List<MenuItem>>{};
    for (final item in menu) {
      groups.putIfAbsent(item.category ?? 'other', () => []).add(item);
    }
    final order = [...foodCategories.keys, 'other'];
    final sections = order.where(groups.containsKey);

    final facts = restaurantFacts(r);
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: FoodPhoto(
                url: r.photoUrl,
                semanticLabel: 'Photo of ${r.name}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RatingBadge(r.rating),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        facts,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.accentText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (r.address case final address? when address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  address,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ],
              if (r.description case final d? when d.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(d, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        const Divider(indent: 24, endIndent: 24, height: 40),
        if (menu.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This restaurant has no dishes listed yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colors.textSecondary),
            ),
          ),
        for (final slug in sections) ...[
          SectionHeader(title: foodCategories[slug] ?? 'More'),
          DishGrid(
            items: groups[slug]!,
            here: widget.here,
            shrinkWrap: true,
            opensRestaurant: false,
          ),
        ],
      ],
    );
  }
}
