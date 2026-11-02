import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in another app; tests swap it out.
@visibleForTesting
Future<bool> Function(Uri uri) launcher =
    (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Hands [uri] to the app for it (dialer, mail, browser), or says it
/// couldn't.
Future<void> openLink(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launcher(uri);
  } on Exception catch (e) {
    debugPrint('[Link] $uri failed: $e');
  }
  if (opened) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        content: Text(
          uri.scheme == 'tel'
              ? "Couldn't open the phone app."
              : "Couldn't open that link.",
        ),
      ),
    );
}
