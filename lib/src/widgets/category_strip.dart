import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';

/// Icon and short label for each server category.
const categoryLooks = <String, (AssetImage, String)>{
  'rice': (AppIcons.catMeal, 'Rice'),
  'soups-stews': (AppIcons.catSoups, 'Soups'),
  'grills': (AppIcons.catGrills, 'Grills'),
  'pizza-burgers': (AppIcons.catBurgers, 'Burgers'),
  'snacks': (AppIcons.catSnacks, 'Snacks'),
  'desserts': (AppIcons.catDessert, 'Dessert'),
  'drinks': (AppIcons.catDrinks, 'Drinks'),
};

/// The kit's category row (3-A, 4.4): cream capsules with line icons, the
/// selected one yellow. Tapping the selected one again clears it.
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Bounce at the ends: Android's stretch squashed the end cards.
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categoryLooks.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final slug = categoryLooks.keys.elementAt(i);
          final isSelected = slug == selected;
          return _Capsule(
            slug: slug,
            selected: isSelected,
            onTap: () => onSelected(isSelected ? null : slug),
          );
        },
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.slug,
    required this.selected,
    required this.onTap,
  });

  final String slug;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (icon, label) = categoryLooks[slug]!;
    // Dark mode: an orange tint, not the field brown, which matched the
    // header so closely that capsules seemed to slide over it when the row
    // scrolled up to the panel's edge.
    final idle = dark ? AppColors.orange.withValues(alpha: 0.16) : colors.field;
    return Semantics(
      button: true,
      selected: selected,
      label: foodCategories[slug],
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 62,
                height: 76,
                decoration: BoxDecoration(
                  color: selected ? AppColors.yellow : idle,
                  borderRadius: BorderRadius.circular(31),
                ),
                child: Center(
                  child: ImageIcon(icon, size: 42, color: AppColors.orange),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
