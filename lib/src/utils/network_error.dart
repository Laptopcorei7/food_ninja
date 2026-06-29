import 'dart:async';
import 'dart:io';

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
