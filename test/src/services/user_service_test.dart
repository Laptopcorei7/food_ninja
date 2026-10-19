import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/utils/network_error.dart';

import '../../helpers/fake_server.dart';

void main() {
  final users = UserService();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().logout(); // clears the static in-memory token
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
  });

  test('getMe returns the user', () async {
    final server = FakeServer(
      (_) async => FakeServer.reply(200, {
        'success': true,
        'data': {
          'user': {'firstName': 'Ama'},
        },
      }),
    );
    final user = await server.run(users.getMe);
    expect(user['firstName'], 'Ama');
    expect(server.last.headers['Authorization'], 'Bearer tok');
  });

  test('getMe 401 is a SessionExpiredException', () async {
    final server = FakeServer((_) async => FakeServer.reply(401));
    await expectLater(
      server.run(users.getMe),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('updateLocation sends address and coordinates', () async {
    final server = FakeServer((_) async => FakeServer.reply(200));
    await server.run(() => users.updateLocation('KNUST, Kumasi', 6.67, -1.57));
    expect(server.last.method, 'PATCH');
    expect(server.lastJson, {
      'address': 'KNUST, Kumasi',
      'lat': 6.67,
      'lng': -1.57,
    });
  });

  test('a card added before its details leaves brand and last4 out', () async {
    final server = FakeServer((_) async => FakeServer.reply(201));
    await server.run(() => users.addPaymentMethod('card'));
    expect(server.lastJson, {'type': 'card'});
  });

  group('uploadPhoto', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('upload_test');
    });
    tearDown(() => dir.delete(recursive: true));

    Future<String> photo(String name) async {
      final file = File('${dir.path}/$name');
      await file.writeAsBytes([0xFF, 0xD8, 0xFF]);
      return file.path;
    }

    // bug-012: without a content type the server's image filter refuses it.
    for (final (name, type) in [
      ('me.jpg', 'image/jpeg'),
      ('me.PNG', 'image/png'),
      ('me.webp', 'image/webp'),
      ('me.heic', 'image/jpeg'),
    ]) {
      test('$name goes up as $type', () async {
        final server = FakeServer((_) async => FakeServer.reply(200));
        final path = await photo(name);
        await server.run(() => users.uploadPhoto(path));
        final body = String.fromCharCodes(server.last.bodyBytes);
        expect(body, contains('name="photo"'));
        expect(body, contains('content-type: $type'));
        expect(server.last.headers['Authorization'], 'Bearer tok');
      });
    }

    test('a rejected photo shows the server message', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(400, {'message': 'Images only'}),
      );
      final path = await photo('me.jpg');
      await expectLater(
        server.run(() => users.uploadPhoto(path)),
        throwsA(
          isA<Exception>().having((e) => '$e', 'text', contains('Images only')),
        ),
      );
    });
  });
}
