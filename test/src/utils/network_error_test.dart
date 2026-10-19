import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:http/http.dart' as http;

void main() {
  group('decodeBody', () {
    test('returns a JSON object', () {
      expect(decodeBody(http.Response('{"a":1}', 200)), {'a': 1});
    });

    test('an HTML page becomes an empty map', () {
      expect(decodeBody(http.Response('<html>502</html>', 502)), isEmpty);
    });

    test('a JSON array becomes an empty map', () {
      expect(decodeBody(http.Response('[1,2]', 200)), isEmpty);
    });
  });

  group('toUserError', () {
    test('a timeout asks the user to check their connection', () {
      expect(
        '${toUserError(TimeoutException('x'))}',
        contains('taking too long'),
      );
    });

    test('a socket error says there is no internet', () {
      expect(
        '${toUserError(const SocketException('x'))}',
        contains('No internet connection'),
      );
    });

    test('other exceptions pass through', () {
      final e = Exception('kept');
      expect(toUserError(e), same(e));
    });

    test('errors that are not exceptions get a generic message', () {
      final message = '${toUserError(StateError('x'))}';
      expect(message, contains('Something went wrong'));
    });
  });

  test('both custom exceptions read as plain messages', () {
    expect('${SessionExpiredException()}', contains('Session expired'));
    expect('${RateLimitException('Slow down')}', 'Exception: Slow down');
  });
}
