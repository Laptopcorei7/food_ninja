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
      // Check for a stored token; if found skip onboarding and go straight to home.
      home: FutureBuilder<String?>(
        future: AuthService().getToken(),
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
          return snapshot.data != null
              ? const HomeScreen()
              : const LoadingScreen();
        },
      ),
    );
  }
}
