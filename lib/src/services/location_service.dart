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

/// Where an order goes: a saved address ([id] and [label] set), the
/// phone's position, or the address given at sign-up.
@immutable
class DeliveryAddress {
  const DeliveryAddress({
    required this.address,
    required this.lat,
    required this.lng,
    this.id,
    this.label,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        id: json['_id'] as String?,
        label: json['label'] as String?,
        address: json['address'] as String? ?? '',
        lat: (json['latitude'] as num?)?.toDouble() ?? 0,
        lng: (json['longitude'] as num?)?.toDouble() ?? 0,
      );

  final String? id;
  final String? label;
  final String address;
  final double lat;
  final double lng;

  Map<String, Object?> toJson() =>
      {'address': address, 'latitude': lat, 'longitude': lng};
}

/// "4 Liberation Road, Osu, Accra": street, area and city, skipping blanks
/// and repeats.
String formatPlacemark(Placemark place) {
  final parts = <String>[];
  for (final part in [place.street, place.subLocality, place.locality]) {
    if (part != null && part.isNotEmpty && !parts.contains(part)) {
      parts.add(part);
    }
  }
  return parts.join(', ');
}

class LocationService {
  // Late: only needed after a GPS fix, and creating it needs the platform.
  late final _geocoding = Geocoding();

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

  /// True when location is on and the app may use it (asking if needed).
  Future<bool> _gpsAllowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<Position?> _gps() async {
    if (!await _gpsAllowed()) return null;
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
    final saved = await signUpAddress();
    if (saved == null) {
      throw Exception(
        "Couldn't find your location. Turn on location and try again.",
      );
    }
    return Here(
      lat: saved.lat,
      lng: saved.lng,
      area: _shorten(saved.address),
      fromGps: false,
    );
  }

  /// The address given at sign-up, or null when it has no position.
  Future<DeliveryAddress?> signUpAddress() async {
    final user = await UserService().getMe();
    final location = user['location'] as Map<String, dynamic>?;
    if (location == null ||
        location['latitude'] is! num ||
        location['longitude'] is! num) {
      return null;
    }
    return DeliveryAddress.fromJson(location);
  }

  /// The street the phone is on, for delivery: the last known position at
  /// once, then a fresh fix, since the user may have moved (a fresh fix
  /// alone can time out right after the permission prompt). Empty when GPS
  /// is off or refused, or no street is found.
  Stream<DeliveryAddress> currentAddress() async* {
    if (!await _gpsAllowed()) return;
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      if (await _addressAt(last) case final found?) yield found;
    }
    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (await _addressAt(fresh) case final found?) yield found;
    } on TimeoutException {
      debugPrint('[LocationService] no fresh fix, keeping the last known');
    }
  }

  Future<DeliveryAddress?> _addressAt(Position position) async {
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final address = places.isEmpty ? '' : formatPlacemark(places.first);
      if (address.isEmpty) return null;
      return DeliveryAddress(
        address: address,
        lat: position.latitude,
        lng: position.longitude,
      );
    } on PlatformException catch (e) {
      debugPrint('[LocationService] geocoding failed: $e');
      return null;
    }
  }

  /// [address] placed on the map, or null when the geocoder can't find it.
  Future<DeliveryAddress?> locate(String address) async {
    try {
      final found = await _geocoding.locationFromAddress(address);
      if (found.isEmpty) return null;
      return DeliveryAddress(
        address: address,
        lat: found.first.latitude,
        lng: found.first.longitude,
      );
    } on Exception catch (e) {
      debugPrint('[LocationService] no position for "$address": $e');
      return null;
    }
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
