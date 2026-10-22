import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// 9.3: the dishes the user saved with the heart. Reloads each time the
/// tab is shown and after coming back from a dish.
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({required this.here, required this.active, super.key});

  final Here? here;

  /// True while this tab is the one on screen.
  final bool active;

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  List<MenuItem>? _items;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(FavoritesTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final items = await CatalogService().favorites(
        lat: widget.here?.lat,
        lng: widget.here?.lng,
      );
      if (mounted) setState(() => _items = items);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Favorites] load failed: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MenuItem item) async {
    await openDish(context, item, widget.here);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Favorites',
      showBack: false,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final items = _items;
    if (_error != null && items == null) {
      return _Note(
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (items == null) {
      // Nothing until the tab is first shown: a spinner on the hidden tab
      // would animate for nothing.
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink();
    }
    if (items.isEmpty) {
      return const _Note(
        text: 'No favourites yet. Tap the heart on a dish to keep it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        itemCount: items.length,
        itemBuilder: (context, i) =>
            DishRow(item: items[i], onTap: () => _open(items[i])),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.colors.textSecondary,
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
