import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

/// Dims the screen with an orange spinner in the middle. The caller
/// dismisses it with Navigator.of(context).pop() when ready.
Future<void> showLoadingOverlay(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.orange),
    ),
  );
}

/// The kit's confirm panel (4.1.1-S "Are you sure you want to log out?"):
/// centred text, then Cancel (peach) and the action (orange) side by side.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.success = false,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryIsDestructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Shows the orange check above the title.
  final bool success;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Kept for callers; the kit draws destructive actions orange too, and the
  /// title already says what happens.
  final bool primaryIsDestructive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    Widget button(String label, VoidCallback onTap, ButtonTone tone) =>
        MajorButton(
          horizontal: 12,
          vertical: 8,
          textonButton: label,
          tone: tone,
          onPress: onTap,
        );

    return Dialog(
      backgroundColor: context.colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (success) ...[
              const ImageIcon(
                AppIcons.checkCircle,
                size: 64,
                color: AppColors.orange,
              ),
              const SizedBox(height: 16),
            ],
            Text(title, textAlign: TextAlign.center, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (hasSecondary)
              Row(
                children: [
                  Expanded(
                    child: button(
                      secondaryLabel!,
                      onSecondary!,
                      ButtonTone.soft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: button(primaryLabel, onPrimary, ButtonTone.primary),
                  ),
                ],
              )
            else
              SizedBox(
                width: 200,
                child: button(primaryLabel, onPrimary, ButtonTone.primary),
              ),
          ],
        ),
      ),
    );
  }
}
