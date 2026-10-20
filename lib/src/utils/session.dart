import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';

/// Signs out after the server rejected the login (401) and goes back to the
/// welcome screen.
Future<void> signOutExpired(BuildContext context) async {
  final nav = Navigator.of(context);
  await AuthService().logout();
  await nav.pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
}

/// Asks first, then signs out and goes back to the welcome screen.
Future<void> confirmLogOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      primaryLabel: 'Yes, log out',
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
  await nav.pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
}
