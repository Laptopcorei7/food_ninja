import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';

/// The kit's orange bar with five outline icons. The kit draws no current
/// tab, so the current one sits on a yellow circle, the way the kit marks a
/// chosen food category.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({required this.index, required this.onTap, super.key});

  final int index;
  final ValueChanged<int> onTap;

  static const List<(AssetImage, String)> tabs = [
    (AppIcons.navHome, 'Home'),
    (AppIcons.navMenu, 'Menu'),
    (AppIcons.navFavorites, 'Favorites'),
    (AppIcons.navOrders, 'My orders'),
    (AppIcons.navSupport, 'Help'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _Tab(
                  icon: tabs[i].$1,
                  label: tabs[i].$2,
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AssetImage icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _fade = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      // excludeSemantics also hides the InkResponse's tap, so give it here or
      // TalkBack can't open the tab.
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: AnimatedContainer(
            duration: _fade,
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.yellow : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: TweenAnimationBuilder<Color?>(
              duration: _fade,
              tween: ColorTween(
                end: selected ? AppColors.brown : Colors.white,
              ),
              builder: (context, color, child) =>
                  ImageIcon(icon, size: 26, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
