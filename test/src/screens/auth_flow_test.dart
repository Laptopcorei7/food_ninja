import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/screens/forgot_password_screen.dart';
import 'package:food_ninja/src/screens/new_password_screen.dart';
import 'package:food_ninja/src/screens/onboarding_screen.dart';
import 'package:food_ninja/src/screens/payment_method_screen.dart';
import 'package:food_ninja/src/screens/sign_in_screen.dart';
import 'package:food_ninja/src/screens/sign_up_process_screen.dart';
import 'package:food_ninja/src/screens/sign_up_screen.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/screens/verification_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().logout();
  });

  group('onboarding', () {
    testWidgets('Next walks the pages, Get Started opens welcome',
        (tester) async {
      await tester.pumpApp(const OnboardingScreen());
      expect(find.text('Order For Food'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Easy Payment'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Fast Delivery'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding'), isTrue);
    });

    testWidgets('Skip remembers onboarding and opens welcome', (tester) async {
      await tester.pumpApp(const OnboardingScreen());
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding'), isTrue);
    });
  });

  testWidgets('welcome opens log in and sign up', (tester) async {
    await tester.pumpApp(const WelcomeScreen());
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  group('log in', () {
    testWidgets('empty fields ask for email and password', (tester) async {
      await tester.pumpApp(const SignInScreen());
      await tester.tap(find.widgetWithText(InkWell, 'Log In'));
      await tester.pump();
      expect(
        find.text('Please enter your email and password'),
        findsOneWidget,
      );
    });

    testWidgets("a wrong password shows the server's message", (tester) async {
      final server = FakeServer(
        (_) async => FakeServer.reply(401, {
          'success': false,
          'message': 'Invalid email or password',
        }),
      );
      await tester.pumpApp(const SignInScreen());
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'nope');
      await server.run(() async {
        await tester.tap(find.widgetWithText(InkWell, 'Log In'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    // bug-015: an account that quit sign-up partway resumes where it left.
    testWidgets('an unfinished account resumes at its missing step',
        (tester) async {
      final server = FakeServer((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return FakeServer.reply(200, {
            'success': true,
            'data': {'token': 'tok'},
          });
        }
        return FakeServer.reply(200, {
          'success': true,
          'data': {
            'user': {'email': 'a@b.co'},
          },
        });
      });
      await tester.pumpApp(const SignInScreen());
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await server.run(() async {
        await tester.tap(find.widgetWithText(InkWell, 'Log In'));
        await tester.pumpAndSettle();
      });
      expect(find.byType(SignUpProcessScreen), findsOneWidget);
      expect(find.text('Your Details'), findsOneWidget);
    });

    testWidgets('the eye shows and hides the password', (tester) async {
      await tester.pumpApp(const SignInScreen());
      TextField password() =>
          tester.widget<TextField>(find.byType(TextField).at(1));
      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(password().obscureText, isFalse);
    });

    testWidgets('Forgot password? opens with the typed email', (tester) async {
      await tester.pumpApp(const SignInScreen());
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      final screen = tester.widget<ForgotPasswordScreen>(
        find.byType(ForgotPasswordScreen),
      );
      expect(screen.email, 'a@b.co');
    });
  });

  testWidgets('sign up with an empty form explains what is missing',
      (tester) async {
    await tester.pumpApp(const SignUpScreen());
    await tester.tap(find.widgetWithText(InkWell, 'Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Missing Fields'), findsOneWidget);
  });

  testWidgets('set password refuses two different passwords', (tester) async {
    final server = FakeServer((_) async => FakeServer.reply(200));
    await tester.pumpApp(const NewPasswordScreen(resetToken: 'rt'));
    await tester.enterText(find.byType(TextField).at(0), 'newpass1');
    await tester.enterText(find.byType(TextField).at(1), 'newpass2');
    await tester.tap(find.text('Create New Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords Differ'), findsOneWidget);
    expect(server.requests, isEmpty);
  });

  testWidgets('forgot password checks the email before sending',
      (tester) async {
    await tester.pumpApp(const ForgotPasswordScreen(email: 'not-an-email'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Check Your Email'), findsOneWidget);
  });

  testWidgets('code screen masks the email and asks for 4 digits',
      (tester) async {
    final server = FakeServer(
      (_) async => FakeServer.reply(200, {'success': true}),
    );
    await server.run(() async {
      await tester.pumpApp(
        const VerificationScreen(contact: 'ama@b.co', resetMethod: 'email'),
      );
      await tester.pump();
    });
    expect(find.textContaining('a****@b.co'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(server.last.url.path, '/api/v1/auth/forgot-password');
    // Remove the screen so its countdown timer stops.
    await tester.pumpWidget(const SizedBox());
  });

  group('payment method', () {
    testWidgets('Next without a choice asks for one', (tester) async {
      await tester.pumpApp(const PaymentMethodScreen());
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Select a Method'), findsOneWidget);
    });

    testWidgets('tapping a row selects it for screen readers too',
        (tester) async {
      await tester.pumpApp(const PaymentMethodScreen());
      final handle = tester.ensureSemantics();
      await tester.tap(find.text('Bank card'));
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Bank card')),
        matchesSemantics(
          label: 'Bank card',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  // bug-016: fixed heights overflowed the test phone. Every step-2 screen
  // must fit a 360 x 640 phone, in both themes.
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final screens = <String, Widget>{
      'onboarding': const OnboardingScreen(),
      'welcome': const WelcomeScreen(),
      'log in': const SignInScreen(),
      'sign up': const SignUpScreen(),
      'your details': const SignUpProcessScreen(),
      'set password': const NewPasswordScreen(resetToken: 'rt'),
      'forgot password': const ForgotPasswordScreen(),
      'payment method': const PaymentMethodScreen(),
      'profile photo': const UploadPhotoScreen(),
      'signup success': const SignupSuccessScreen(),
      'splash': const SplashScreen(),
    };
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets('$name fits a small phone ($mode)', (tester) async {
        tester.useSmallPhone();
        await tester.pumpApp(screen, dark: dark);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
