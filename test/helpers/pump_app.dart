import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/theme/app_theme.dart';

extension PumpApp on WidgetTester {
  /// Shows [child] as a screen of the app, in the dark theme when [dark].
  Future<void> pumpApp(Widget child, {bool dark = false}) {
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
    );
  }
}
