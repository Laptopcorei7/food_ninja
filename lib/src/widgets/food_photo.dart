import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/api_url.dart';

/// A dish, restaurant or profile photo. It fills its box, fades in, and
/// shows a plain tile with [fallbackIcon] when there is no photo or it fails
/// to load.
class FoodPhoto extends StatelessWidget {
  const FoodPhoto({
    required this.url,
    this.semanticLabel,
    this.fallbackIcon = AppIcons.utensils,
    super.key,
  });

  final String? url;
  final String? semanticLabel;
  final AssetImage fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: context.colors.soft,
      child: Center(
        child: ImageIcon(fallbackIcon, color: AppColors.orange, size: 28),
      ),
    );
    final src = mediaUrl(url);
    if (src == null) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        src,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        // Decode near the shown size (bug-018: full-size decodes were evicted
        // from the cache, so photos downloaded again). x2 leaves room for
        // BoxFit.cover cropping a landscape photo.
        cacheWidth: constraints.hasBoundedWidth
            ? (constraints.maxWidth * dpr * 2).round()
            : null,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[FoodPhoto] $src failed: $error');
          return fallback;
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}
