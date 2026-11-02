import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// The kit's row of pills: the chosen one orange, the others peach.
/// [tabs] maps each value to its label.
class TabPills extends StatelessWidget {
  const TabPills({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final Map<String, String> tabs;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final MapEntry(key: tab, value: label) in tabs.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                selected: tab == selected,
                button: true,
                child: Material(
                  color: tab == selected ? AppColors.orange : colors.soft,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(tab),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          color: tab == selected
                              ? Colors.white
                              : colors.accentText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
