import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/utils/network_error.dart';

import '../../helpers/fake_server.dart';

void main() {
  late AuthService auth;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    auth = AuthService();
    // The no-"keep me signed in" token is static; start each test without it.
    await auth.logout();
  });

  Matcher throwsMessage(String text) => throwsA(
        isA<Exception>().having((e) => '$e', 'message', contains(text)),
      );

  group('login', () {
    final ok = FakeServer(
      (_) async => FakeServer.reply(200, {
        'success': true,
        'data': {'token': 'abc', 'user': <String, dynamic>{}},
      }),
    );

    test('sends email and password as JSON', () async {
      await ok.run(() => auth.login('a@b.co', 'secret1'));
      expect(ok.last.method, 'POST');
      expect(ok.last.url.path, '/api/v1/auth/login');
      expect(ok.lastJson, {'email': 'a@b.co', 'password': 'secret1'});
    });

    test('keep signed in stores the token on the device', () async {
      await ok.run(() => auth.login('a@b.co', 'secret1'));
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), 'abc');
      expect(await auth.getToken(), 'abc');
    });

    test('without keep signed in the token lives only in memory', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'old'});
      await ok.run(() => auth.login('a@b.co', 'secret1', keepSignedIn: false));
      final stored = await const FlutterSecureStorage().read(key: 'auth_token');
      expect(stored, isNull);
      expect(await auth.getToken(), 'abc');
    });

    test('logout forgets both kinds of token', () async {
      await ok.run(() => auth.login('a@b.co', 'secret1', keepSignedIn: false));
      await auth.logout();
      expect(await auth.getToken(), isNull);
    });

    test("shows the server's message on a wrong password", () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(401, {
          'success': false,
          'message': 'Invalid email or password',
        }),
      );
      await expectLater(
        server.run(() => auth.login('a@b.co', 'nope')),
        throwsMessage('Invalid email or password'),
      );
    });

    test('an HTML error page never reaches the user', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(502, '<html>Bad Gateway</html>'),
      );
      await expectLater(
        server.run(() => auth.login('a@b.co', 'secret1')),
        throwsMessage('Login failed. Please try again.'),
      );
    });

    test('no connection becomes a readable message', () async {
      final server = FakeServer(
        (_) async => throw const SocketException('Network is unreachable'),
      );
      await expectLater(
        server.run(() => auth.login('a@b.co', 'secret1')),
        throwsMessage('No internet connection'),
      );
    });
  });

  group('signup', () {
    test('stores the token and returns the data on 201', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(201, {
          'success': true,
          'data': {'token': 'new'},
        }),
      );
      final data = await server.run(
        () => auth.signup('Ama', 'ama@b.co', 'secret1'),
      );
      expect(data['token'], 'new');
      expect(server.lastJson['name'], 'Ama');
      expect(await auth.getToken(), 'new');
    });

    test('409 says the email is taken', () async {
      final server = FakeServer((_) async => FakeServer.reply(409));
      await expectLater(
        server.run(() => auth.signup('Ama', 'ama@b.co', 'secret1')),
        throwsMessage('already registered'),
      );
    });
  });

  group('OTP', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    });

    test('sends the phone with the login token', () async {
      final server = FakeServer((_) async => FakeServer.reply(200));
      await server.run(() => auth.sendOtp('+233241234567'));
      expect(server.last.headers['Authorization'], 'Bearer tok');
      expect(server.lastJson, {'phone': '+233241234567'});
    });

    test('needs a login first', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = FakeServer((_) async => FakeServer.reply(200));
      await expectLater(
        server.run(() => auth.sendOtp('+233241234567')),
        throwsMessage('Not logged in'),
      );
      expect(server.requests, isEmpty);
    });

    test('429 is a RateLimitException with the server text', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(429, {
          'message': 'Too many attempts, try again in 15 minutes',
        }),
      );
      await expectLater(
        server.run(() => auth.sendOtp('+233241234567')),
        throwsA(
          isA<RateLimitException>().having(
            (e) => e.message,
            'message',
            'Too many attempts, try again in 15 minutes',
          ),
        ),
      );
    });

    test('an expired code (410) says to request a new one', () async {
      final server = FakeServer((_) async => FakeServer.reply(410));
      await expectLater(
        server.run(() => auth.verifyOtp('1234')),
        throwsMessage('expired'),
      );
    });

    test('a wrong code shows the server message', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(400, {'message': 'Incorrect code'}),
      );
      await expectLater(
        server.run(() => auth.verifyOtp('0000')),
        throwsMessage('Incorrect code'),
      );
    });

    // Current behaviour: OTP calls report a 401 as a plain Exception, not
    // SessionExpiredException like the other services.
    test('401 says the session expired', () async {
      final server = FakeServer((_) async => FakeServer.reply(401));
      await expectLater(
        server.run(() => auth.verifyOtp('1234')),
        throwsMessage('Session expired'),
      );
    });
  });

  group('forgot password', () {
    test('requesting a code sends no login token', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {'success': true}),
      );
      await server.run(
        () => auth.requestPasswordReset('email', 'ama@b.co'),
      );
      expect(server.last.url.path, '/api/v1/auth/forgot-password');
      expect(server.last.headers.containsKey('Authorization'), isFalse);
      expect(server.lastJson, {'method': 'email', 'contact': 'ama@b.co'});
    });

    test('a correct code returns the reset token', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {
          'success': true,
          'data': {'resetToken': 'rt-1'},
        }),
      );
      final token = await server.run(
        () => auth.verifyResetCode('ama@b.co', '1234'),
      );
      expect(token, 'rt-1');
    });

    test('429 on a reset call is a RateLimitException', () async {
      final server = FakeServer((_) async => FakeServer.reply(429));
      await expectLater(
        server.run(() => auth.requestPasswordReset('sms', '+233241234567')),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('resetPassword sends both password fields', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {'success': true}),
      );
      await server
          .run(() => auth.resetPassword('rt-1', 'newpass1', 'newpass1'));
      expect(server.lastJson, {
        'resetToken': 'rt-1',
        'newPassword': 'newpass1',
        'confirmPassword': 'newpass1',
      });
    });
  });

  test('deleteAccount signs out even when the server is unreachable', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    final server = FakeServer(
      (_) async => throw TimeoutException('slow'),
    );
    await server.run(auth.deleteAccount);
    expect(await auth.getToken(), isNull);
  });
}
