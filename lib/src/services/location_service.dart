import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Where the user is, and whether that came from GPS or the saved address.
@immutable
class Here {
  const Here({
    required this.lat,
    required this.lng,
    required this.area,
    required this.fromGps,
  });

  final double lat;
  final double lng;

  /// A short place name for the header, e.g. "East Legon".
  final String area;

  /// False when GPS was off or refused and the address saved at sign-up is
  /// used instead.
  final bool fromGps;
}

class LocationService {
  final _geocoding = Geocoding();

  /// The phone's position, or the saved address when GPS is off, refused or
  /// too slow. Throws only when neither is available.
  Future<Here> here() async {
    try {
      final position = await _gps();
      if (position != null) {
        return Here(
          lat: position.latitude,
          lng: position.longitude,
          area: await _areaFor(position.latitude, position.longitude),
          fromGps: true,
        );
      }
    } on Exception catch (e) {
      debugPrint('[LocationService] GPS failed, using saved address: $e');
    }
    return await _saved();
  }

  Future<Position?> _gps() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    // A fresh fix can take a while indoors; the last known one is close
    // enough to rank restaurants by distance.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      return null;
    }
  }

  Future<Here> _saved() async {
    final user = await UserService().getMe();
    final location = user['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw Exception(
        "Couldn't find your location. Turn on location and try again.",
      );
    }
    final address = location?['address'] as String? ?? '';
    return Here(
      lat: lat,
      lng: lng,
      area: _shorten(address),
      fromGps: false,
    );
  }

  /// The neighbourhood ("East Legon"), else the town, else ''.
  Future<String> _areaFor(double lat, double lng) async {
    try {
      final places = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return '';
      final place = places.first;
      for (final part in [place.subLocality, place.locality]) {
        if (part != null && part.isNotEmpty) return part;
      }
    } on PlatformException catch (e) {
      debugPrint('[LocationService] geocoding failed: $e');
    }
    return '';
  }

  /// "4 Liberation Road, Osu, Accra" -> "Osu".
  String _shorten(String address) {
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) return parts[parts.length - 2];
    return parts.isEmpty ? '' : parts.first;
  }
}
