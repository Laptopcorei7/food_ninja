import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';

/// The kit's orange price pill on dish photos.
class PriceTag extends StatelessWidget {
  const PriceTag(this.amount, {super.key});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 2),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        formatCedis(amount),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// "4.5 ★" in the kit's small orange pill.
class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 5, 1),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.star_rounded, size: 13, color: AppColors.yellow),
        ],
      ),
    );
  }
}

/// A section title with an optional "View all" link (3-A).
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.onViewAll, super.key});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      color: context.colors.textPrimary,
                    ),
              ),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.accentText,
              ),
              child: Semantics(
                label: 'View all $title',
                excludeSemantics: true,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A dish as a photo card with its price, name and restaurant (3-A best
/// seller and recommended, 6-A). The photo is [photoHeight] tall.
class DishTile extends StatelessWidget {
  const DishTile({
    required this.item,
    this.onTap,
    this.photoHeight = 108,
    this.showRating = false,
    super.key,
  });

  final MenuItem item;

  /// Null makes the card plain, not a button.
  final VoidCallback? onTap;
  final double photoHeight;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final from = item.restaurantName;
    return Semantics(
      button: onTap != null,
      label: [
        item.name,
        if (from != null) 'from $from',
        formatCedis(item.price),
        if (showRating) 'rated ${item.rating.toStringAsFixed(1)}',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: photoHeight,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodPhoto(url: item.photoUrl),
                    if (showRating)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: RatingBadge(item.rating),
                      ),
                    Positioned(
                      right: 6,
                      bottom: 8,
                      child: PriceTag(item.price),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Flexible: the tile always has a set height, and very large
            // system text clips here instead of overflowing the card.
            Flexible(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (from != null)
                      Text(
                        from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dish in the Menu list (9.2): wide photo, name, rating, price,
/// description, then where it comes from.
class DishRow extends StatelessWidget {
  const DishRow({required this.item, required this.onTap, super.key});

  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final from = [
      if (item.restaurantName != null) item.restaurantName!,
      if (item.distanceKm != null) formatKm(item.distanceKm!),
    ].join(' · ');
    return Semantics(
      button: true,
      label: [
        item.name,
        'rated ${item.rating.toStringAsFixed(1)}',
        formatCedis(item.price),
        if (from.isNotEmpty) from,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: FoodPhoto(url: item.photoUrl),
                ),
              ),
              const SizedBox(height: 12),
              // Top-aligned so the badge and price sit on the name's first
              // line when a long name wraps.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: RatingBadge(item.rating),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCedis(item.price),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: colors.accentText,
                    ),
                  ),
                ],
              ),
              if (item.description case final description?
                  when description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (from.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  from,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.accentText,
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

/// A restaurant as a photo card: name, rating, distance and delivery time.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    required this.restaurant,
    required this.onTap,
    this.photoHeight = 110,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final double photoHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = restaurant;
    final facts = restaurantFacts(r);
    return Semantics(
      button: true,
      label: [r.name, 'rated ${r.rating.toStringAsFixed(1)}', facts]
          .where((s) => s.isNotEmpty)
          .join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: photoHeight,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodPhoto(url: r.photoUrl),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: RatingBadge(r.rating),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (facts.isNotEmpty)
              Text(
                facts,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// "1.2 km · 25 min", leaving out what is unknown.
String restaurantFacts(Restaurant r) => [
      if (r.distanceKm != null) formatKm(r.distanceKm!),
      if (r.deliveryTimeMins != null) '${r.deliveryTimeMins} min',
    ].join(' · ');
