import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/screens/onboarding_screen.dart';
import 'package:food_ninja/src/screens/payment_method_screen.dart';
import 'package:food_ninja/src/screens/set_location_screen.dart';
import 'package:food_ninja/src/screens/sign_in_screen.dart';
import 'package:food_ninja/src/screens/sign_up_process_screen.dart';
import 'package:food_ninja/src/screens/sign_up_screen.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/screens/upload_preview_screen.dart';
import 'package:food_ninja/src/screens/verification_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _StartRoute { onboarding, login, home }

Future<_StartRoute> _resolveStartRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  if (!seenOnboarding) return _StartRoute.onboarding;
  final token = await AuthService().getToken();
  return token != null ? _StartRoute.home : _StartRoute.login;
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF53E88B)),
        useMaterial3: true,
      ),
      routes: {
        '/onboarding': (context) => const LoadingScreen(),
        '/login': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/process': (context) => const SignUpProcessScreen(),
        '/verify': (context) => const VerificationScreen(phoneNumber: ''),
        '/payment-method': (context) => const PaymentMethodScreen(),
        '/upload-photo': (context) => const UploadPhotoScreen(),
        '/upload-preview': (context) => const UploadPreviewScreen(),
        '/set-location': (context) => const SetLocationScreen(),
        '/signup-success': (context) => const SignupSuccessScreen(),
        '/home': (context) => const HomeScreen(),
      },
      home: FutureBuilder<_StartRoute>(
        future: _resolveStartRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF53E88B)),
                ),
              ),
            );
          }
          return switch (snapshot.data) {
            _StartRoute.home => const HomeScreen(),
            _StartRoute.login => const SignInScreen(),
            _ => const LoadingScreen(),
          };
        },
      ),
    );
  }
}
