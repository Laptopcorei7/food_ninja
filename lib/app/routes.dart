import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/forgot_password_screen.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/screens/new_password_screen.dart';
import 'package:food_ninja/src/screens/onboarding_screen.dart';
import 'package:food_ninja/src/screens/payment_method_screen.dart';
import 'package:food_ninja/src/screens/set_location_screen.dart';
import 'package:food_ninja/src/screens/sign_in_screen.dart';
import 'package:food_ninja/src/screens/sign_up_process_screen.dart';
import 'package:food_ninja/src/screens/sign_up_screen.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/screens/upload_preview_screen.dart';
import 'package:food_ninja/src/screens/verification_screen.dart';

/// Route names. Navigate with `Navigator.pushNamed(context, AppRoutes.home)`.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const signIn = '/login';
  static const signUp = '/signup';
  static const signUpProcess = '/process';
  static const verify = '/verify';
  static const paymentMethod = '/payment-method';
  static const uploadPhoto = '/upload-photo';
  static const uploadPreview = '/upload-preview';
  static const setLocation = '/set-location';
  static const signUpSuccess = '/signup-success';
  static const home = '/home';
  static const forgotPassword = '/forgot-password';
  static const resetCode = '/reset-code';
  static const newPassword = '/new-password';

  /// The screen for a route name. `verify` takes the phone number,
  /// `uploadPreview` the image path and `uploadPhoto` an optional recovered
  /// photo path as the argument. `forgotPassword` takes an optional email,
  /// `resetCode` a (method, contact) record and `newPassword` the reset token.
  static Widget? page(String? name, Object? arg) => switch (name) {
        onboarding => const LoadingScreen(),
        signIn => const SignInScreen(),
        signUp => const SignUpScreen(),
        signUpProcess => const SignUpProcessScreen(),
        verify => VerificationScreen(contact: arg! as String),
        paymentMethod => const PaymentMethodScreen(),
        uploadPhoto => UploadPhotoScreen(recoveredImagePath: arg as String?),
        uploadPreview => UploadPreviewScreen(imagePath: arg as String?),
        setLocation => const SetLocationScreen(),
        signUpSuccess => const SignupSuccessScreen(),
        home => const HomeScreen(),
        forgotPassword => ForgotPasswordScreen(email: arg as String?),
        resetCode => switch (arg! as (String, String)) {
            (final method, final contact) =>
              VerificationScreen(contact: contact, resetMethod: method),
          },
        newPassword => NewPasswordScreen(resetToken: arg! as String),
        _ => null,
      };

  /// The first unfinished sign-up step for a GET users/me user, as a route
  /// name and its argument, or null when sign-up is complete.
  static (String, Object?)? setupStepFor(Map<String, dynamic> user) {
    final phone = user['phone'] as String?;
    if (user['firstName'] == null || phone == null) {
      return (signUpProcess, null);
    }
    if (user['phoneVerified'] != true) return (verify, phone);
    if ((user['paymentMethods'] as List?)?.isEmpty ?? true) {
      return (paymentMethod, null);
    }
    if (user['photo'] == null) return (uploadPhoto, null);
    if (user['location'] == null) return (setLocation, null);
    return null;
  }

  static Route<void>? onGenerateRoute(RouteSettings settings) {
    final page = AppRoutes.page(settings.name, settings.arguments);
    if (page == null) return null;

    // Sign in and sign up fade into each other; AuthLayout slides the form.
    if (settings.name == signIn || settings.name == signUp) {
      return PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }
}
