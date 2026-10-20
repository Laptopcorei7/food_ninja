import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/onboarding_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_theme.dart';
import 'package:food_ninja/src/theme/theme_cubit.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Set by the "fresh start" launch config and `run_dev.ps1 -fresh` so the
// first-run path (onboarding, sign up) can be tested on every launch.
const _freshStart = bool.fromEnvironment('FRESH_START');

/// Android may close the app to free memory while the camera is open. The
/// photo survives, and image_picker hands it back after the restart.
Future<String?> _lostPhoto() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final lost = await ImagePicker().retrieveLostData();
    return lost.isEmpty ? null : lost.file?.path;
  } on Exception catch (e) {
    debugPrint('[App] retrieveLostData failed: $e');
    return null;
  }
}

/// The first screen, as a route name and its argument.
Future<(String, Object?)> _resolveStartRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthService();
  // Checked before the fresh-start reset, which would sign the user out.
  final photo = await _lostPhoto();
  if (photo != null && await auth.getToken() != null) {
    return (AppRoutes.uploadPhoto, photo);
  }
  if (kDebugMode && _freshStart) {
    await prefs.remove('has_seen_onboarding');
    await auth.logout();
  }
  final seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  if (!seenOnboarding) return (AppRoutes.onboarding, null);
  if (await auth.getToken() == null) return (AppRoutes.welcome, null);

  // Resume an unfinished sign-up at its first missing step.
  try {
    final user = await UserService().getMe();
    return AppRoutes.setupStepFor(user) ?? (AppRoutes.home, null);
  } on SessionExpiredException {
    // The account is gone or the login expired: start from sign in.
    await auth.logout();
    return (AppRoutes.signIn, null);
  } on Exception catch (e) {
    // Offline or server down: don't lock the user out.
    debugPrint('[App] profile check failed, opening home: $e');
    return (AppRoutes.home, null);
  }
}

// Resolved once: App rebuilds on every theme change and must not re-run this.
// The splash stays at least 900 ms so it doesn't flash.
final Future<(String, Object?)> _startRoute = (
  _resolveStartRoute(),
  Future<void>.delayed(const Duration(milliseconds: 900)),
).wait.then((results) => results.$1);

class App extends StatelessWidget {
  const App({required this.themeCubit, super.key});

  final ThemeCubit themeCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: themeCubit,
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // Country names and messages for the phone field.
          localizationsDelegates: PhoneFieldLocalization.delegates,
          home: FutureBuilder<(String, Object?)>(
            future: _startRoute,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SplashScreen();
              }
              final (name, arg) = snapshot.data ?? (AppRoutes.onboarding, null);
              return AppRoutes.page(name, arg)!;
            },
          ),
        ),
      ),
    );
  }
}
