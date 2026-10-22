import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';

/// Home's top-right buttons: search, cart, notifications and profile.
class ShopHeader extends StatelessWidget {
  const ShopHeader({
    required this.onSearch,
    required this.onCart,
    required this.onBell,
    required this.onProfile,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onCart;
  final VoidCallback onBell;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 14, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          HeaderIconButton(
            icon: AppIcons.search,
            tooltip: 'Search',
            onTap: onSearch,
          ),
          ValueListenableBuilder(
            valueListenable: CatalogService.cartCount,
            builder: (context, count, _) {
              final n = count ?? 0;
              return Badge(
                isLabelVisible: n > 0,
                label: Text(n > 99 ? '99+' : '$n'),
                backgroundColor: AppColors.orange,
                textColor: Colors.white,
                offset: const Offset(-2, 2),
                child: HeaderIconButton(
                  icon: AppIcons.cart,
                  tooltip: n > 0 ? 'Cart, $n items' : 'Cart',
                  onTap: onCart,
                ),
              );
            },
          ),
          HeaderIconButton(
            icon: AppIcons.bell,
            tooltip: 'Notifications',
            onTap: onBell,
          ),
          HeaderIconButton(
            icon: AppIcons.user,
            tooltip: 'Profile and settings',
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

/// The kit's small white rounded-square button with an orange icon, with a
/// 48 px tap area.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final AssetImage icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 48),
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          // White on the kit's yellow; in dark mode the page colour, since
          // the dark surface is too close to the dark header to see.
          color: dark ? colors.background : colors.surface,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: ImageIcon(icon, size: 20, color: AppColors.orange),
      ),
    );
  }
}
