import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';

// Placeholder home screen — will be replaced with the full home UI
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Log Out',
        message: 'Are you sure you want to log out?',
        primaryLabel: 'Log Out',
        primaryIsDestructive: true,
        secondaryLabel: 'Cancel',
        onPrimary: () => Navigator.of(ctx).pop(true),
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    await AuthService().logout();
    if (!context.mounted) return;
    nav.pop(); // dismiss overlay
    await nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Home Screen\n(coming soon)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BentonSansBold',
                fontSize: 22,
                color: Color(0xFF53E88B),
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => _handleLogout(context),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'BentonSansMedium',
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
