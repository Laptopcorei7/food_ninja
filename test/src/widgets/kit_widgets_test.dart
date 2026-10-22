import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/app_bottom_nav.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';
import 'package:food_ninja/src/widgets/yumquick_logo.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('MajorButton', () {
    Color fillOf(WidgetTester tester) => tester
        .widget<Material>(
          find.descendant(
            of: find.byType(MajorButton),
            matching: find.byType(Material),
          ),
        )
        .color!;

    testWidgets('primary is orange with white text and taps', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: MajorButton(
            horizontal: 40,
            vertical: 10,
            textonButton: 'Log In',
            onPress: () => taps++,
          ),
        ),
      );
      expect(fillOf(tester), AppColors.orange);
      expect(
        tester.widget<Text>(find.text('Log In')).style?.color,
        Colors.white,
      );
      await tester.tap(find.text('Log In'));
      expect(taps, 1);
    });

    testWidgets('soft uses the theme peach and readable orange text',
        (tester) async {
      await tester.pumpApp(
        const Center(
          child: MajorButton(
            horizontal: 40,
            vertical: 10,
            textonButton: 'Skip',
            tone: ButtonTone.soft,
          ),
        ),
      );
      expect(fillOf(tester), AppColors.light.soft.withValues(alpha: 0.5));
      expect(
        tester.widget<Text>(find.text('Skip')).style?.color,
        AppColors.light.accentText,
      );
    });

    testWidgets('soft follows dark mode', (tester) async {
      await tester.pumpApp(
        MajorButton(
          horizontal: 40,
          vertical: 10,
          textonButton: 'Skip',
          tone: ButtonTone.soft,
          onPress: () {},
        ),
        dark: true,
      );
      expect(fillOf(tester), AppColors.dark.soft);
    });
  });

  group('AppBottomNav', () {
    testWidgets('has the five kit tabs and reports taps', (tester) async {
      int? tapped;
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNav(
            index: 0,
            onTap: (i) => tapped = i,
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      for (final label in ['Home', 'Menu', 'Favorites', 'My orders', 'Help']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('My orders'));
      expect(tapped, 3);
      handle.dispose();
    });

    testWidgets('marks only the current tab as selected', (tester) async {
      await tester.pumpApp(
        Scaffold(bottomNavigationBar: AppBottomNav(index: 2, onTap: (_) {})),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Favorites')),
        matchesSemantics(
          label: 'Favorites',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        matchesSemantics(
          label: 'Home',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('SheetScaffold', () {
    testWidgets('shows title and subtitle on the header colour',
        (tester) async {
      await tester.pumpApp(
        const SheetScaffold(
          title: 'Help & FAQs',
          subtitle: 'How Can We Help You?',
          child: SizedBox(),
        ),
      );
      expect(find.text('Help & FAQs'), findsOneWidget);
      expect(find.text('How Can We Help You?'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Help & FAQs')).style?.color,
        AppColors.light.onHeader,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.yellow,
      );
    });

    testWidgets('no back arrow on the first screen', (tester) async {
      await tester
          .pumpApp(const SheetScaffold(title: 'Home', child: SizedBox()));
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('back arrow pops a pushed screen', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const SheetScaffold(title: 'Settings', child: SizedBox()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('a long title stays on one line without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const SheetScaffold(
          title: 'Delivery Address Delivery Address Delivery Address',
          child: SizedBox(),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode uses the dark header', (tester) async {
      await tester.pumpApp(
        const SheetScaffold(title: 'Settings', child: SizedBox()),
        dark: true,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.dark.header,
      );
    });

    for (final dark in [false, true]) {
      testWidgets(
          'status bar icons show on the ${dark ? 'brown' : 'yellow'} header',
          (tester) async {
        await tester.pumpApp(
          const SheetScaffold(title: 'Menu', child: SizedBox()),
          dark: dark,
        );
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(
          region.value.statusBarIconBrightness,
          dark ? Brightness.light : Brightness.dark,
        );
      });
    }
  });

  testWidgets('YumQuickLogo reads as one name to screen readers',
      (tester) async {
    await tester.pumpApp(const Center(child: YumQuickLogo()));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('YumQuick'), findsOneWidget);
    handle.dispose();
  });
}
