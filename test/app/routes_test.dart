import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/screens/verification_screen.dart';

void main() {
  // bug-015: a restart mid sign-up resumes at the first missing step.
  group('setupStepFor', () {
    final done = <String, dynamic>{
      'firstName': 'Ama',
      'phone': '+233241234567',
      'phoneVerified': true,
      'paymentMethods': [
        {'type': 'card'},
      ],
      'photo': 'uploads/a.jpg',
      'location': {'address': 'KNUST'},
    };

    Map<String, dynamic> without(String key) => {...done}..remove(key);

    test('a finished account goes straight to Home', () {
      expect(AppRoutes.setupStepFor(done), isNull);
    });

    test('no name or phone: the profile step', () {
      expect(
        AppRoutes.setupStepFor(without('firstName')),
        (
          AppRoutes.signUpProcess,
          null,
        ),
      );
      expect(
        AppRoutes.setupStepFor(without('phone')),
        (
          AppRoutes.signUpProcess,
          null,
        ),
      );
    });

    test('unverified phone: the code screen, with the phone', () {
      expect(
        AppRoutes.setupStepFor({...done, 'phoneVerified': false}),
        (AppRoutes.verify, '+233241234567'),
      );
    });

    test('no payment method: the payment step', () {
      expect(
        AppRoutes.setupStepFor({...done, 'paymentMethods': <Object>[]}),
        (AppRoutes.paymentMethod, null),
      );
      expect(
        AppRoutes.setupStepFor(without('paymentMethods')),
        (
          AppRoutes.paymentMethod,
          null,
        ),
      );
    });

    test('then photo, then location', () {
      expect(
        AppRoutes.setupStepFor(without('photo')),
        (
          AppRoutes.uploadPhoto,
          null,
        ),
      );
      expect(
        AppRoutes.setupStepFor(without('location')),
        (
          AppRoutes.setLocation,
          null,
        ),
      );
    });
  });

  group('page', () {
    test('maps names to screens and passes arguments', () {
      expect(AppRoutes.page(AppRoutes.home, null), isA<HomeScreen>());
      final verify = AppRoutes.page(AppRoutes.verify, '+233241234567');
      expect(
        verify,
        isA<VerificationScreen>()
            .having((s) => s.contact, 'contact', '+233241234567')
            .having((s) => s.resetMethod, 'resetMethod', isNull),
      );
    });

    test('a reset code route carries the method', () {
      expect(
        AppRoutes.page(AppRoutes.resetCode, ('sms', '+233241234567')),
        isA<VerificationScreen>()
            .having((s) => s.resetMethod, 'resetMethod', 'sms'),
      );
    });

    test('an unknown name has no page', () {
      expect(AppRoutes.page('/nope', null), isNull);
      expect(
        AppRoutes.onGenerateRoute(const RouteSettings(name: '/nope')),
        isNull,
      );
    });
  });
}
