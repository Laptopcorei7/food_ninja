import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/radius_map.dart';

/// A restaurant in Home's sheet and in search results.
class PlaceRow extends StatelessWidget {
  const PlaceRow({required this.restaurant, super.key});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final kinds = r.categories
        .map((c) => foodCategories[c])
        .whereType<String>()
        .take(2)
        .join(', ');
    return _RowCard(
      photoUrl: r.photoUrl,
      title: r.name,
      subtitle: [
        '★ ${r.rating.toStringAsFixed(1)}',
        if (kinds.isNotEmpty) kinds,
      ].join(' · '),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (r.distanceKm != null)
            Text(
              formatKm(r.distanceKm!),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.greenDark,
              ),
            ),
          if (r.deliveryTimeMins != null) ...[
            const SizedBox(height: 4),
            Text(
              '${r.deliveryTimeMins} min',
              style:
                  TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// A menu item in Home's sheet and in search results.
class DishRow extends StatelessWidget {
  const DishRow({required this.item, super.key});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      photoUrl: item.photoUrl,
      title: item.name,
      subtitle: [
        if (item.restaurantName != null) item.restaurantName!,
        if (item.distanceKm != null) formatKm(item.distanceKm!),
      ].join(' · '),
      trailing: Text(
        formatCedis(item.price),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.greenDark,
        ),
      ),
    );
  }
}

/// A chip in Home's sheet and the search screen. Selected chips are the
/// brand gradient ([accent]) or solid text colour; the rest are the kit's
/// orange on the search-field cream.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fg;
    final Decoration box;
    if (selected && accent) {
      fg = Colors.white;
      box = BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(17),
      );
    } else if (selected) {
      fg = colors.background;
      box = BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(17),
      );
    } else {
      fg = AppColors.orange;
      box = BoxDecoration(
        color: colors.searchField,
        borderRadius: BorderRadius.circular(17),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: box,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.photoUrl,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String? photoUrl;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 56,
              child: RestaurantPhoto(url: photoUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
