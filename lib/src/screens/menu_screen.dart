import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/category_strip.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

const sortLabels = {
  'popular': 'Popular',
  'rating': 'Top rated',
  'distance': 'Nearest',
};

/// 9.2: every dish near you, by category and sorted.
class MenuTab extends StatefulWidget {
  const MenuTab({
    required this.here,
    required this.error,
    required this.onRetry,
    required this.filter,
    required this.onFilterChanged,
    required this.actions,
    super.key,
  });

  final Here? here;
  final String? error;
  final VoidCallback onRetry;
  final MenuFilter filter;
  final ValueChanged<MenuFilter> onFilterChanged;
  final ShopActions actions;

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  final _catalog = CatalogService();
  Future<List<MenuItem>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MenuTab old) {
    super.didUpdateWidget(old);
    if (widget.here != old.here || widget.filter != old.filter) _load();
  }

  void _load() {
    final here = widget.here;
    if (here == null) return;
    setState(() {
      _items = _catalog.menuItems(
        lat: here.lat,
        lng: here.lng,
        filter: widget.filter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.here?.area;
    return SheetScaffold(
      headerHeight: ShopTabHeader.height,
      header: ShopTabHeader(
        actions: widget.actions,
        title: 'Menu',
        line: area == null || area.isEmpty
            ? 'Dishes near you'
            : 'Dishes near $area',
      ),
      child: Column(
        children: [
          const SizedBox(height: 34),
          CategoryStrip(
            selected: widget.filter.category,
            onSelected: (c) => widget
                .onFilterChanged(widget.filter.copyWith(category: () => c)),
          ),
          _sortRow(),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _sortRow() {
    final colors = context.colors;
    final f = widget.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
      child: Row(
        children: [
          Text('Sort by', style: TextStyle(color: colors.textPrimary)),
          PopupMenuButton<String>(
            tooltip: 'Sort by',
            initialValue: f.sort,
            onSelected: (s) => widget.onFilterChanged(f.copyWith(sort: s)),
            itemBuilder: (context) => [
              for (final MapEntry(:key, :value) in sortLabels.entries)
                PopupMenuItem(value: key, child: Text(value)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Text(
                    sortLabels[f.sort] ?? f.sort,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.accentText,
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: colors.accentText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final here = widget.here;
    if (here == null) {
      return widget.error == null
          ? const LoadingSpinner()
          : LoadError(message: widget.error!, onRetry: widget.onRetry);
    }
    return FutureBuilder<List<MenuItem>>(
      future: _items,
      builder: (context, snap) {
        if (snap.error case final error?) {
          if (error is SessionExpiredException) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => signOutExpired(context));
          }
          debugPrint('[Menu] load failed: $error');
          return LoadError(
            message: "Couldn't load the menu. Check your connection.",
            onRetry: _load,
          );
        }
        final items = snap.data;
        if (items == null) return const LoadingSpinner();
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Nothing near you matches. Try another category or clear '
                'the filters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () async {
            _load();
            await _items;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            itemCount: items.length,
            separatorBuilder: (context, i) => const Divider(height: 8),
            itemBuilder: (context, i) => DishRow(
              item: items[i],
              onTap: () => openDish(context, items[i], here),
            ),
          ),
        );
      },
    );
  }
}
