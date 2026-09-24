import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// The kit's floating nav (1.22, 1.43): the current tab is a pale green pill
/// with its name, the others are icons only.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.index,
    required this.onTap,
    this.cartCount = 0,
    this.unreadChats = 0,
    super.key,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int cartCount;
  final int unreadChats;

  static const List<(IconData, String)> _tabs = [
    (Icons.home_rounded, 'Home'),
    (Icons.person_rounded, 'Profile'),
    (Icons.shopping_cart_rounded, 'Cart'),
    (Icons.chat_bubble_rounded, 'Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(15, 0, 15, 15),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x1A5A6CEA),
                    blurRadius: 50,
                    offset: Offset(0, -4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _Tab(
                icon: _tabs[i].$1,
                label: _tabs[i].$2,
                selected: i == index,
                badge: switch (i) {
                  2 => cartCount,
                  3 => unreadChats,
                  _ => 0,
                },
                onTap: () => onTap(i),
              ),
          ],
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
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  static const _fade = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final iconWidget = Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: AppColors.error,
      child: Icon(icon, color: AppColors.green, size: 24),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: _fade,
          curve: Curves.easeOutCubic,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: _fade,
                opacity: selected ? 1 : 0.45,
                child: iconWidget,
              ),
              // The label fades in while the pill grows to fit it.
              AnimatedSize(
                duration: _fade,
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: _fade,
                  child: selected
                      ? Padding(
                          key: const ValueKey(true),
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey(false)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
