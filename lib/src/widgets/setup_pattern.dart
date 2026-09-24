import 'package:flutter/material.dart';

/// Food pattern across the top of the sign-up setup screens (1.6-1.10).
/// Put it first in a Stack. The lines are pale green, so in dark mode they
/// are dimmed to the dark green of the 2.x designs.
class SetupPattern extends StatelessWidget {
  const SetupPattern({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: dark ? 0.2 : 1,
        child: Image.asset(
          'assets/images/pattern_2.png',
          fit: BoxFit.cover,
          height: 250,
          width: 200,
        ),
      ),
    );
  }
}
