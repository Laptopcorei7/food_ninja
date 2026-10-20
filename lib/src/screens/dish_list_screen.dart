import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

class DishListArgs {
  const DishListArgs({
    required this.title,
    required this.intro,
    required this.sort,
    required this.here,
  });

  final String title;
  final String intro;

  /// 'popular' or 'rating'.
  final String sort;
  final Here here;
}

/// 6-A Best Seller and 8-A Recommendations: a grid of dishes near you.
class DishListScreen extends StatefulWidget {
  const DishListScreen({required this.args, super.key});

  final DishListArgs args;

  @override
  State<DishListScreen> createState() => _DishListScreenState();
}

class _DishListScreenState extends State<DishListScreen> {
  late Future<List<MenuItem>> _items = _fetch();

  Future<List<MenuItem>> _fetch() {
    final a = widget.args;
    return CatalogService().menuItems(
      lat: a.here.lat,
      lng: a.here.lng,
      filter: MenuFilter(sort: a.sort),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return SheetScaffold(
      title: a.title,
      child: FutureBuilder<List<MenuItem>>(
        future: _items,
        builder: (context, snap) {
          if (snap.error case final error?) {
            if (error is SessionExpiredException) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => signOutExpired(context));
            }
            debugPrint('[DishList] load failed: $error');
            return LoadError(
              message: "Couldn't load the dishes. Check your connection.",
              onRetry: () => setState(() {
                _items = _fetch();
              }),
            );
          }
          final items = snap.data;
          if (items == null) return const LoadingSpinner();
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  a.intro,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.colors.accentText,
                  ),
                ),
              ),
              DishGrid(items: items, here: a.here, shrinkWrap: true),
            ],
          );
        },
      ),
    );
  }
}
