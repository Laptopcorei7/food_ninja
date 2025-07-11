import 'package:flutter/material.dart';
import 'package:food_ninja/l10n/l10n.dart';
import 'package:food_ninja/src/screens/onboarding_screen.dart';
import 'package:food_ninja/src/screens/sign_in_screen.dart';
import 'package:food_ninja/src/screens/sign_up_process_screen.dart';
import 'package:food_ninja/src/screens/sign_up_screen.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/screens/upload_preview_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SignupSuccessScreen(),
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/signup',
      // routes: {
      //   '/uploadpreview': (context) => const UploadPreviewScreen(),
      //   '/uploadphoto': (context) => const UploadPhotoScreen(),
      //   '/onboarding': (context) => const LoadingScreen(),
      //   '/login': (context) => const SignInScreen(),
      //   '/signup': (context) => const SignUpScreen(),
      //   '/process': (context) => const SignUpProcessScreen(),
      // },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
