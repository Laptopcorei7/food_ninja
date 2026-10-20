import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/filter_screen.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

typedef _Results = (List<Restaurant>, List<MenuItem>);

/// Search by name across restaurants and dishes near [here], with the
/// Filter screen (4.4) narrowing the dishes.
class SearchScreen extends StatefulWidget {
  const SearchScreen({required this.here, super.key});

  final Here here;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _catalog = CatalogService();
  final _query = TextEditingController();
  Timer? _debounce;
  Future<_Results>? _results;
  MenuFilter _filter = const MenuFilter();

  bool get _filtered => _filter != const MenuFilter();

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing so each key press isn't a request.
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  void _search(String text) {
    final q = text.trim();
    setState(() {
      // Filters alone are a search too: every dish that matches them.
      _results = q.length < 2 && !_filtered ? null : _fetch(q);
    });
  }

  Future<_Results> _fetch(String q) async {
    final h = widget.here;
    // Restaurants match by name only, so they need typed text.
    final places = q.length < 2
        ? Future.value(const <Restaurant>[])
        : _catalog.restaurants(lat: h.lat, lng: h.lng, search: q, limit: 10);
    final dishes = _catalog.menuItems(
      lat: h.lat,
      lng: h.lng,
      search: q,
      filter: _filter,
    )..ignore();
    return (await places, await dishes);
  }

  Future<void> _openFilter() async {
    // A typed route, not a named one: onGenerateRoute builds Route<void>,
    // which can't return the filter.
    final result = await Navigator.of(context).push(
      MaterialPageRoute<MenuFilter>(
        builder: (_) => FilterScreen(
          args: FilterArgs(filter: _filter, here: widget.here),
        ),
      ),
    );
    if (result == null || !mounted) return;
    _filter = result;
    _search(_query.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SheetScaffold(
      headerHeight: 72,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
        child: Row(
          children: [
            CustomBackButton(onTap: () => Navigator.of(context).maybePop()),
            Expanded(
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Search dishes and restaurants',
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        const BorderSide(color: AppColors.orange, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _filtered,
              backgroundColor: colors.onHeader,
              smallSize: 10,
              child: IconButton.filled(
                tooltip: _filtered ? 'Filter, on' : 'Filter',
                onPressed: _openFilter,
                style: IconButton.styleFrom(backgroundColor: AppColors.orange),
                icon: const ImageIcon(
                  AppIcons.filter,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    final results = _results;
    if (results == null) {
      return _note('Type at least 2 letters, like "jollof" or a '
          "restaurant's name, or use the filter.");
    }
    return FutureBuilder<_Results>(
      future: results,
      builder: (context, snap) {
        if (snap.error case final error?) {
          if (error is SessionExpiredException) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => signOutExpired(context));
          }
          debugPrint('[Search] failed: $error');
          return LoadError(
            message: "Couldn't search right now. Check your connection.",
            onRetry: () => _search(_query.text),
          );
        }
        final data = snap.data;
        if (data == null) return const LoadingSpinner();
        final (places, dishes) = data;
        if (places.isEmpty && dishes.isEmpty) {
          final q = _query.text.trim();
          return _note(
            q.isEmpty
                ? 'Nothing near you matches these filters.'
                : 'Nothing near you matches "$q".',
          );
        }
        final here = widget.here;
        return ListView(
          padding: const EdgeInsets.only(top: 24, bottom: 32),
          children: [
            if (places.isNotEmpty) ...[
              const SectionHeader(title: 'Restaurants'),
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  // Bounce at the ends: Android's stretch squashed the end cards.
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: places.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => SizedBox(
                    width: 180,
                    child: RestaurantCard(
                      restaurant: places[i],
                      onTap: () => openRestaurant(context, places[i].id, here),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (dishes.isNotEmpty) ...[
              const SectionHeader(title: 'Dishes'),
              DishGrid(items: dishes, here: here, shrinkWrap: true),
            ],
          ],
        );
      },
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: context.colors.textSecondary),
        ),
      );
}
