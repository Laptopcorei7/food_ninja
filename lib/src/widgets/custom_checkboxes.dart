import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// Round check in the kit's colours, with its label. The whole row toggles.
class CustomCheckbox extends StatelessWidget {
  const CustomCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: Semantics(
        checked: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? AppColors.orange : Colors.transparent,
                    border: Border.all(
                      color: value ? AppColors.orange : colors.textSecondary,
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The kit's radio: orange ring, filled centre when chosen.
class KitRadio extends StatelessWidget {
  const KitRadio({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.orange, width: 1.5),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: selected ? 1 : 0,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.orange,
          ),
        ),
      ),
    );
  }
}

/// A row of the kit's pick lists (4.1.1-J, 4.1.1-L): icon, title, an
/// optional second line, and a [KitRadio]. The whole row is the target.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 36, child: Center(child: leading)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (subtitle case final s?)
                        Text(
                          s,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                KitRadio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
