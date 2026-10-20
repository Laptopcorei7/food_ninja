import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class SetLocationScreen extends StatefulWidget {
  const SetLocationScreen({super.key});

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final TextEditingController _locationController = TextEditingController();
  final _userService = UserService();
  final _geocoding = Geocoding();

  bool _locating = false;
  String? _status;
  double _lat = 0;
  double _lng = 0;

  /// The last address filled in automatically; if the field still holds it,
  /// a better fix may replace it.
  String _autoFilled = '';

  @override
  void initState() {
    super.initState();
    unawaited(_detect());
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  /// Fills the address from the phone's GPS. The user can still edit it
  /// (e.g. add a house number) or type it if location access is refused.
  Future<void> _detect() async {
    setState(() {
      _locating = true;
      _status = 'Finding your location...';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setStatus('Location is off. Turn it on, or type your address.');
        await _offerSettings(
          'Location Is Off',
          'Turn on location to find your address automatically.',
          Geolocator.openLocationSettings,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setStatus('Allow location access, or type your address.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setStatus('Location access is blocked. Type your address.');
        await _offerSettings(
          'Location Access Needed',
          'Allow location in Settings to find your address automatically.',
          Geolocator.openAppSettings,
        );
        return;
      }

      // A GPS that was just switched on often needs longer than a normal wait
      // indoors, which made the first try fail. Show the phone's last known
      // position at once, then refine it with a fresh fix.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) await _useFix(last);
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
        await _useFix(fresh);
      } on TimeoutException {
        if (last == null) rethrow;
        debugPrint('[SetLocation] no fresh fix, keeping last known position');
      }
    } on Exception catch (e) {
      debugPrint('[SetLocation] detect failed: $e');
      _setStatus("Couldn't find your location. Try again or type it.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Stores the position and fills the address, unless the user has edited
  /// the field since the last automatic fill.
  Future<void> _useFix(Position position) async {
    _lat = position.latitude;
    _lng = position.longitude;
    final address = await _addressFor(_lat, _lng);
    if (!mounted) return;
    if (_locationController.text == _autoFilled) {
      _locationController.text = address;
      _autoFilled = address;
    }
    _setStatus(
      address.isEmpty
          ? 'Found your position. Type your street to finish.'
          : null,
    );
  }

  /// Street address for a position. The phone's geocoder sometimes fails the
  /// first call (e.g. still connecting), so it gets one retry.
  Future<String> _addressFor(double lat, double lng) async {
    for (var attempt = 1;; attempt++) {
      try {
        final places = await _geocoding.placemarkFromCoordinates(lat, lng);
        return places.isEmpty ? '' : _format(places.first);
      } on PlatformException catch (e) {
        if (attempt == 2) rethrow;
        debugPrint('[SetLocation] geocoding failed, retrying: $e');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// "4 Liberation Road, Osu, Accra": street, area and city, skipping blanks
  /// and repeats.
  String _format(Placemark place) {
    final parts = <String>[];
    for (final part in [place.street, place.subLocality, place.locality]) {
      if (part != null && part.isNotEmpty && !parts.contains(part)) {
        parts.add(part);
      }
    }
    return parts.join(', ');
  }

  void _setStatus(String? status) {
    if (mounted) setState(() => _status = status);
  }

  Future<void> _offerSettings(
    String title,
    String message,
    Future<bool> Function() open,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        message: message,
        primaryLabel: 'Open Settings',
        onPrimary: () {
          Navigator.of(ctx).pop();
          unawaited(open());
        },
        secondaryLabel: 'Type It Instead',
        onSecondary: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _handleNext() async {
    final address = _locationController.text.trim();

    if (address.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Enter Location',
          message: 'Tap Set Location or type your delivery address.',
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      // lat/lng stay 0 when the address was typed without GPS.
      await _userService.updateLocation(address, _lat, _lng);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.pushNamed(AppRoutes.signUpSuccess);
    } on Object catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Error',
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'Try Again',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SetupLayout(
      title: 'Your Location',
      intro: 'Where should we deliver? We fill it in from your phone, and you '
          'can edit it.',
      onButton: _handleNext,
      children: [
        // Kit 4.1.1-K: the big outline icon over the form.
        const Center(
          child: ImageIcon(
            AppIcons.location,
            size: 88,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          controller: _locationController,
          label: 'Address',
          hint: 'Street, area, city',
          autofillHints: const [AutofillHints.fullStreetAddress],
          textInputAction: TextInputAction.done,
        ),
        if (_status != null) ...[
          Text(
            _status!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: TextButton.icon(
            onPressed: _locating ? null : _detect,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.orange,
                    ),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: const Text('Use my current location'),
            style: TextButton.styleFrom(
              foregroundColor: colors.accentText,
              backgroundColor: colors.soft,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
