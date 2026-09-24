import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A 401: the saved login is no longer valid (expired, or the account is
/// gone, e.g. after a database reset). Callers that can recover sign out.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Exception: Session expired. Please log in again.';
}

/// A 429: too many attempts from this device. [message] is the server's
/// ("Too many attempts, try again in 15 minutes"), shown as-is.
class RateLimitException implements Exception {
  RateLimitException(this.message);
  final String message;

  @override
  String toString() => 'Exception: $message';
}

/// Parses a JSON object response body. Anything else (an HTML error page, a
/// stack trace) returns an empty map, so callers fall back to their own
/// message and the raw text never reaches the user.
Map<String, dynamic> decodeBody(http.Response response) {
  try {
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) return body;
  } on FormatException {
    // Not JSON; logged below.
  }
  if (kDebugMode) {
    debugPrint(
      '[network] ${response.statusCode} non-JSON body from '
      '${response.request?.url}: ${response.body}',
    );
  }
  return const {};
}

/// Converts low-level network exceptions into user-readable messages.
/// Use inside every catch block that wraps an HTTP request.
Exception toUserError(Object e) {
  if (e is TimeoutException) {
    return Exception(
      'This is taking too long. Please check your internet connection and try again.',
    );
  }
  if (e is SocketException) {
    return Exception(
      'No internet connection. Please check your network and try again.',
    );
  }
  if (e is Exception) return e;
  return Exception('Something went wrong. Please try again.');
}
