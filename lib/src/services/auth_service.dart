import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // DEV_HOST is injected by scripts/run_dev.ps1 via --dart-define.
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
            body: jsonEncode(
              {'name': name, 'email': email, 'password': password},
            ),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    final body = decodeBody(response);

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

  // Token for a sign in without "Keep me signed in": lives until the app closes.
  static String? _sessionToken;

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool keepSignedIn = true,
  }) async {
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
    } catch (e) {
      throw toUserError(e);
    }

    final body = decodeBody(response);

    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      if (keepSignedIn) {
        _sessionToken = null;
        await _storage.write(key: _tokenKey, value: token);
      } else {
        _sessionToken = token;
        await _storage.delete(key: _tokenKey);
      }
      return data;
    }

    throw Exception(
      (body['message'] as String?) ?? 'Login failed. Please try again.',
    );
  }

  Future<String?> getToken() async =>
      _sessionToken ?? await _storage.read(key: _tokenKey);

  // Logout is local-only — it just deletes the stored token from the device.
  // It does not make a network request and cannot fail due to poor internet.
  Future<void> logout() {
    _sessionToken = null;
    return _storage.delete(key: _tokenKey);
  }

  Future<void> sendOtp(String phone) async {
    if (kDebugMode) debugPrint('[AuthService] POST $_baseUrl/auth/otp/send');
    final token = await getToken();
    if (token == null) throw Exception('Not logged in.');

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/auth/otp/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (response.statusCode != 200) {
      _throwIfRateLimited(response);
      final body = decodeBody(response);
      throw Exception((body['message'] as String?) ?? 'Failed to send OTP.');
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (kDebugMode) debugPrint('[AuthService] POST $_baseUrl/auth/otp/verify');
    final token = await getToken();
    if (token == null) throw Exception('Not logged in.');

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/auth/otp/verify'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    if (response.statusCode == 200) return;

    _throwIfRateLimited(response);
    final body = decodeBody(response);
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (response.statusCode == 410) {
      throw Exception('Your OTP has expired. Please request a new one.');
    }
    throw Exception(
      (body['message'] as String?) ?? 'Incorrect code. Please try again.',
    );
  }

  /// Sends a 4-digit reset code by [method] ('sms' or 'email') to [contact]
  /// (E.164 phone or email). The server answers the same whether or not an
  /// account exists, so this succeeds for unknown contacts too.
  Future<void> requestPasswordReset(String method, String contact) =>
      _postPublic(
        'auth/forgot-password',
        {'method': method, 'contact': contact},
        'Failed to send the code. Please try again.',
      );

  /// Uses up the reset [code] and returns the reset token (valid 10 minutes).
  /// Keep it in memory only; it is not a login token.
  Future<String> verifyResetCode(String contact, String code) async {
    final body = await _postPublic(
      'auth/forgot-password/verify',
      {'contact': contact, 'code': code},
      'Incorrect code. Please try again.',
    );
    final data = body['data'] as Map<String, dynamic>;
    return data['resetToken'] as String;
  }

  /// Sets the new password. No login token comes back; the user signs in.
  Future<void> resetPassword(
    String resetToken,
    String newPassword,
    String confirmPassword,
  ) =>
      _postPublic(
        'auth/reset-password',
        {
          'resetToken': resetToken,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
        'Failed to reset your password. Please try again.',
      );

  /// POSTs [payload] without an auth header and returns the body of a 200,
  /// or throws the server's message ([fallback] when it has none).
  Future<Map<String, dynamic>> _postPublic(
    String path,
    Map<String, String> payload,
    String fallback,
  ) async {
    if (kDebugMode) debugPrint('[AuthService] POST $_baseUrl/$path');
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    _throwIfRateLimited(response);
    final body = decodeBody(response);
    if (response.statusCode == 200 && body['success'] == true) return body;
    throw Exception((body['message'] as String?) ?? fallback);
  }

  void _throwIfRateLimited(http.Response response) {
    if (response.statusCode != 429) return;
    throw RateLimitException(
      (decodeBody(response)['message'] as String?) ??
          'Too many attempts, try again in 15 minutes',
    );
  }

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
    } on Object catch (_) {
      // Silently ignore — account deletion failure must not block back navigation
    }
    await logout();
  }
}
