import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UserService {
  static const _devHost =
      String.fromEnvironment('DEV_HOST', defaultValue: '10.0.2.2');
  static const _baseUrl = 'http://$_devHost:5000/api/v1';

  Future<String?> _token() => AuthService().getToken();

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _guard401(http.Response response) {
    if (response.statusCode == 401) {
      throw SessionExpiredException();
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    if (kDebugMode) debugPrint('[UserService] GET $_baseUrl/users/me');
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/users/me'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    _guard401(response);
    final body = decodeBody(response);
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

    final http.Response response;
    try {
      response = await http
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
    } catch (e) {
      throw toUserError(e);
    }

    _guard401(response);
    if (response.statusCode == 200) return;
    final body = decodeBody(response);
    throw Exception(
      (body['message'] as String?) ?? 'Failed to update profile.',
    );
  }

  /// The server accepts jpeg, png and webp.
  static MediaType _imageType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
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
      // Without a content type the file goes up as application/octet-stream,
      // which the server's image filter rejects.
      ..files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imagePath,
          contentType: _imageType(imagePath),
        ),
      );

    final http.Response response;
    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      throw toUserError(e);
    }

    if (response.statusCode == 401) {
      throw SessionExpiredException();
    }
    if (response.statusCode == 200) return;
    final body = decodeBody(response);
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

    final http.Response response;
    try {
      response = await http
          .patch(
            Uri.parse('$_baseUrl/users/me/location'),
            headers: _authHeaders(token),
            body: jsonEncode({'address': address, 'lat': lat, 'lng': lng}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    _guard401(response);
    if (response.statusCode == 200) return;
    final body = decodeBody(response);
    throw Exception(
      (body['message'] as String?) ?? 'Failed to update location.',
    );
  }

  /// Leave [brand] and [last4] null for a card whose details are not added
  /// yet; the server then stores them as null.
  Future<void> addPaymentMethod(
    String type, {
    String? brand,
    String? last4,
  }) async {
    if (kDebugMode) {
      debugPrint('[UserService] POST $_baseUrl/users/me/payment-methods');
    }
    final token = await _token();
    if (token == null) throw Exception('Not logged in.');

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/users/me/payment-methods'),
            headers: _authHeaders(token),
            body: jsonEncode({
              'type': type,
              if (brand != null) 'brand': brand,
              if (last4 != null) 'last4': last4,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    _guard401(response);
    if (response.statusCode == 201) return;
    final body = decodeBody(response);
    throw Exception(
      (body['message'] as String?) ?? 'Failed to add payment method.',
    );
  }
}
