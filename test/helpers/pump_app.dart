import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/theme/app_theme.dart';
import 'package:phone_form_field/phone_form_field.dart';

extension PumpApp on WidgetTester {
  /// Shows [child] as a screen of the app, in the dark theme when [dark].
  /// Named routes work, as in the real app.
  Future<void> pumpApp(Widget child, {bool dark = false}) {
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        localizationsDelegates: PhoneFieldLocalization.delegates,
        home: child,
      ),
    );
  }

  /// A small phone (360 x 640 dp), where layouts overflow first.
  void useSmallPhone() {
    view.physicalSize = const Size(360 * 3, 640 * 3);
    view.devicePixelRatio = 3;
    addTearDown(view.reset);
  }
}
