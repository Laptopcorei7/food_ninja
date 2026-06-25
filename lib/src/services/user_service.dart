import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UserService {
  static const _devHost =
      String.fromEnvironment('DEV_HOST', defaultValue: '10.0.2.2');
  static const _baseUrl = 'http://$_devHost:5000/api/v1';
  static const _tokenKey = 'auth_token';

  final _storage = const FlutterSecureStorage();

  Future<String?> _token() => _storage.read(key: _tokenKey);

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _guard401(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    if (kDebugMode) debugPrint('[UserService] GET $_baseUrl/users/me');
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final response = await http
        .get(
          Uri.parse('$_baseUrl/users/me'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    _guard401(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      return (body['data'] as Map<String, dynamic>)['user']
          as Map<String, dynamic>;
    }
    throw Exception(
      (body['message'] as String?) ?? 'Failed to load profile.',
    );
  }

  Future<void> updateProfile(
    String firstName,
    String lastName,
    String phone,
  ) async {
    if (kDebugMode) {
      debugPrint('[UserService] PATCH $_baseUrl/users/me/profile');
    }
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final response = await http
        .patch(
          Uri.parse('$_baseUrl/users/me/profile'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'firstName': firstName,
            'lastName': lastName,
            'phone': phone,
          }),
        )
        .timeout(const Duration(seconds: 15));

    _guard401(response);
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(
      (body['message'] as String?) ?? 'Failed to update profile.',
    );
  }

  Future<void> uploadPhoto(String imagePath) async {
    if (kDebugMode) debugPrint('[UserService] POST $_baseUrl/users/me/photo');
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/users/me/photo'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('photo', imagePath));

    final streamed =
        await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(
      (body['message'] as String?) ?? 'Failed to upload photo.',
    );
  }

  Future<void> updateLocation(
    String address,
    double lat,
    double lng,
  ) async {
    if (kDebugMode) {
      debugPrint('[UserService] PATCH $_baseUrl/users/me/location');
    }
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final response = await http
        .patch(
          Uri.parse('$_baseUrl/users/me/location'),
          headers: _authHeaders(token),
          body: jsonEncode({'address': address, 'lat': lat, 'lng': lng}),
        )
        .timeout(const Duration(seconds: 15));

    _guard401(response);
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(
      (body['message'] as String?) ?? 'Failed to update location.',
    );
  }

  Future<void> addPaymentMethod(
    String type,
    String brand,
    String last4,
  ) async {
    if (kDebugMode) {
      debugPrint('[UserService] POST $_baseUrl/users/me/payment-methods');
    }
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/users/me/payment-methods'),
          headers: _authHeaders(token),
          body: jsonEncode({'type': type, 'brand': brand, 'last4': last4}),
        )
        .timeout(const Duration(seconds: 15));

    _guard401(response);
    if (response.statusCode == 201) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(
      (body['message'] as String?) ?? 'Failed to add payment method.',
    );
  }
}
