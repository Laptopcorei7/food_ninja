import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';

/// The kit's pill buttons.
enum ButtonTone {
  /// Orange with white text: the main action.
  primary,

  /// Peach with orange text: Skip, Cancel, Add New Address.
  soft,

  /// Yellow: Log In on the orange welcome screen (0-B).
  yellow,

  /// Cream: Sign Up on the orange welcome screen (0-B).
  cream,
}

class MajorButton extends StatelessWidget {
  const MajorButton({
    required this.horizontal,
    required this.vertical,
    required this.textonButton,
    this.onPress,
    this.tone = ButtonTone.primary,
    super.key,
  });
  final double horizontal;
  final double vertical;
  final String textonButton;
  final VoidCallback? onPress;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      ButtonTone.primary => (AppColors.orange, Colors.white),
      ButtonTone.soft => (colors.soft, colors.accentText),
      // The kit's orange text on these is 2.4:1 and 3:1; brown reads.
      ButtonTone.yellow => (AppColors.yellow, AppColors.brown),
      ButtonTone.cream => (AppColors.cream, AppColors.brown),
    };
    final enabled = onPress != null;
    return Material(
      color: enabled ? background : background.withValues(alpha: 0.5),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPress,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: vertical,
          ),
          child: Text(
            textonButton,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
