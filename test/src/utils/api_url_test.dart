import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/utils/api_url.dart';

void main() {
  group('mediaUrl', () {
    test('an upload saved with an old address points at the current server',
        () {
      expect(
        mediaUrl('http://192.168.1.131:5000/uploads/me.jpg'),
        '$apiOrigin/uploads/me.jpg',
      );
    });

    test('a relative upload path gets the server address', () {
      expect(mediaUrl('/uploads/me.jpg'), '$apiOrigin/uploads/me.jpg');
    });

    test('web photos pass through', () {
      const unsplash = 'https://images.unsplash.com/photo-1?w=800';
      expect(mediaUrl(unsplash), unsplash);
    });

    test('empty is null', () {
      expect(mediaUrl(''), isNull);
      expect(mediaUrl(null), isNull);
    });
  });
}
