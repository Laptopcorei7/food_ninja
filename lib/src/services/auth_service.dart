import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // DEV_HOST is injected by scripts/run_dev.ps1 (or run_dev.sh) via --dart-define.
  // Falls back to 10.0.2.2 (Android emulator → host machine) when run without the script.
  static const _devHost =
      String.fromEnvironment('DEV_HOST', defaultValue: '10.0.2.2');
  static const _baseUrl = 'http://$_devHost:5000/api/v1';
  static const _tokenKey = 'auth_token';

  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    if (kDebugMode) debugPrint('[AuthService] POST $_baseUrl/auth/signup');
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception('Cannot reach server. Is the backend running?');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      await _storage.write(key: _tokenKey, value: data['token'] as String);
      return data;
    }

    if (response.statusCode == 409) {
      throw Exception('An account with this email is already registered.');
    }

    throw Exception(
      (body['message'] as String?) ?? 'Sign up failed. Please try again.',
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (kDebugMode) debugPrint('[AuthService] POST $_baseUrl/auth/login');
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception('Cannot reach server. Is the backend running?');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      await _storage.write(key: _tokenKey, value: data['token'] as String);
      return data;
    }

    throw Exception(
      (body['message'] as String?) ?? 'Login failed. Please try again.',
    );
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<void> deleteAccount() async {
    if (kDebugMode) debugPrint('[AuthService] DELETE $_baseUrl/auth/account');
    final token = await getToken();
    if (token == null) return;
    try {
      await http.delete(
        Uri.parse('$_baseUrl/auth/account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Silently ignore network errors — user should still be able to go back
    }
    await logout();
  }
}
