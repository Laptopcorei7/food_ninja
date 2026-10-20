import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/utils/network_error.dart';

import '../../helpers/fake_server.dart';

void main() {
  group('formatCedis', () {
    test('whole amounts have no decimals', () {
      expect(formatCedis(50), 'GH₵ 50');
    });
    test('pesewas show two decimals', () {
      expect(formatCedis(12.5), 'GH₵ 12.50');
    });
  });

  group('formatKm', () {
    test('whole kilometres have no decimal', () => expect(formatKm(5), '5 km'));
    test('one decimal otherwise', () => expect(formatKm(0.94), '0.9 km'));
  });

  group('Restaurant.fromJson', () {
    test('reads GeoJSON coordinates as [lng, lat]', () {
      final r = Restaurant.fromJson(const {
        '_id': 'r1',
        'name': 'Buka',
        'location': {
          'type': 'Point',
          'coordinates': [-1.57, 6.67],
        },
        'rating': 4,
        'deliveryTimeMins': 25,
        'categories': ['rice', 'grills'],
        'distanceKm': 1.2,
      });
      expect(r.lat, 6.67);
      expect(r.lng, -1.57);
      expect(r.rating, 4.0);
      expect(r.categories, ['rice', 'grills']);
      expect(r.distanceKm, 1.2);
    });

    test('missing optional fields fall back', () {
      final r = Restaurant.fromJson(const {'_id': 'r1', 'name': 'Buka'});
      expect(r.rating, 0);
      expect(r.lat, isNull);
      expect(r.categories, isEmpty);
      expect(r.distanceKm, isNull);
    });
  });

  group('MenuItem.fromJson', () {
    test('takes the restaurant from the nested object', () {
      final m = MenuItem.fromJson(const {
        '_id': 'm1',
        'name': 'Jollof',
        'price': 45,
        'orderCount': 12,
        'restaurant': {'_id': 'r1', 'name': 'Buka'},
      });
      expect(m.price, 45.0);
      expect(m.restaurantId, 'r1');
      expect(m.restaurantName, 'Buka');
    });

    test('falls back to a bare restaurantId', () {
      final m = MenuItem.fromJson(const {
        '_id': 'm1',
        'name': 'Jollof',
        'restaurantId': 'r9',
      });
      expect(m.restaurantId, 'r9');
      expect(m.restaurantName, isNull);
      expect(m.orderCount, 0);
    });
  });

  group('CatalogService', () {
    final catalog = CatalogService();

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthService().logout(); // clears the static in-memory token
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    });

    FakeServer page(List<Map<String, dynamic>> items) => FakeServer(
          (_) async => FakeServer.reply(200, {
            'success': true,
            'data': {'items': items, 'page': 1, 'totalPages': 1},
          }),
        );

    test('restaurants sends position, radius and search', () async {
      final server = page([
        {'_id': 'r1', 'name': 'Buka'},
      ]);
      final list = await server.run(
        () =>
            catalog.restaurants(lat: 6.67, lng: -1.57, maxKm: 12, search: 'jo'),
      );
      expect(list.single.name, 'Buka');
      final q = server.last.url.queryParameters;
      expect(server.last.url.path, '/api/v1/restaurants');
      expect(q['lat'], '6.67');
      expect(q['lng'], '-1.57');
      expect(q['maxKm'], '12.0');
      expect(q['search'], 'jo');
      expect(q['limit'], '50');
      expect(server.last.headers['Authorization'], 'Bearer tok');
    });

    test('an empty search is left out of the query', () async {
      final server = page([]);
      await server.run(
        () => catalog.menuItems(lat: 6.67, lng: -1.57, search: ''),
      );
      final q = server.last.url.queryParameters;
      expect(q.containsKey('search'), isFalse);
      expect(q['sort'], 'popular');
    });

    test('401 is a SessionExpiredException', () async {
      final server = FakeServer((_) async => FakeServer.reply(401));
      await expectLater(
        server.run(() => catalog.restaurants(lat: 0, lng: 0)),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('no stored token is a SessionExpiredException without a request',
        () async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = page([]);
      await expectLater(
        server.run(() => catalog.restaurants(lat: 0, lng: 0)),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(server.requests, isEmpty);
    });

    test('menuItems sends every filter, and the delivery range by default',
        () async {
      final server = page([]);
      await server.run(
        () => catalog.menuItems(
          lat: 6.67,
          lng: -1.57,
          filter: const MenuFilter(
            category: 'grills',
            sort: 'rating',
            minRating: 4,
            maxPrice: 60,
          ),
        ),
      );
      final q = server.last.url.queryParameters;
      expect(q['category'], 'grills');
      expect(q['sort'], 'rating');
      expect(q['minRating'], '4');
      expect(q['maxPrice'], '60.0');
      expect(q['maxKm'], '$deliveryRangeKm');
    });

    test('forYou asks for the picks near the user', () async {
      final server = page([
        {'_id': 'm1', 'name': 'Waakye'},
      ]);
      final picks = await server.run(
        () => catalog.forYou(lat: 6.67, lng: -1.57, limit: 8),
      );
      expect(picks.single.name, 'Waakye');
      expect(server.last.url.path, '/api/v1/menu-items/for-you');
      expect(server.last.url.queryParameters['limit'], '8');
      expect(server.last.url.queryParameters['lat'], '6.67');
    });

    test('a dish list reads rating and description', () async {
      final server = page([
        {
          '_id': 'm1',
          'name': 'Kebab',
          'price': 30,
          'rating': 4.6,
          'description': 'Beef, pepper, onion',
          'restaurant': {'_id': 'r1', 'name': 'Buka'},
        },
      ]);
      final item =
          (await server.run(() => catalog.menuItems(lat: 0, lng: 0))).single;
      expect(item.rating, 4.6);
      expect(item.description, 'Beef, pepper, onion');
      expect(item.restaurantName, 'Buka');
    });

    test('priceRange reads min and max, ignoring the price filter', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {
          'success': true,
          'data': {
            'items': <Object>[],
            'priceRange': {'min': 5, 'max': 200},
          },
        }),
      );
      final range = await server.run(
        () => catalog.priceRange(
          lat: 0,
          lng: 0,
          filter: const MenuFilter(maxPrice: 20, category: 'drinks'),
        ),
      );
      expect(range, (5.0, 200.0));
      final q = server.last.url.queryParameters;
      expect(q.containsKey('maxPrice'), isFalse);
      expect(q['category'], 'drinks');
    });

    test('priceRange is null when nothing matches', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {
          'success': true,
          'data': {'items': <Object>[], 'priceRange': null},
        }),
      );
      expect(
        await server.run(() => catalog.priceRange(lat: 0, lng: 0)),
        isNull,
      );
    });

    test('restaurant sends the position for its distance', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {
          'success': true,
          'data': {'_id': 'r1', 'name': 'Buka', 'distanceKm': 2.3},
        }),
      );
      final r = await server.run(
        () => catalog.restaurant('r1', lat: 6.67, lng: -1.57),
      );
      expect(r.distanceKm, 2.3);
      expect(server.last.url.path, '/api/v1/restaurants/r1');
      expect(server.last.url.queryParameters['lat'], '6.67');
    });

    test('restaurantMenu reads the plain list with bare restaurant ids',
        () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {
          'success': true,
          'data': [
            {'_id': 'm1', 'name': 'Waakye', 'restaurant': 'r1'},
          ],
          'total': 1,
        }),
      );
      final menu = await server.run(() => catalog.restaurantMenu('r1'));
      expect(menu.single.name, 'Waakye');
      expect(menu.single.restaurantName, isNull);
      expect(server.last.url.path, '/api/v1/restaurants/r1/menu');
    });

    test('vouchers reads the offers', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(200, {
          'success': true,
          'data': [
            {'_id': 'v1', 'title': 'Jollof Friday', 'discountAmount': 10},
          ],
        }),
      );
      final offers = await server.run(catalog.vouchers);
      expect(offers.single.title, 'Jollof Friday');
      expect(offers.single.discountAmount, 10);
    });

    test('a 400 shows the server message', () async {
      final server = FakeServer(
        (_) async => FakeServer.reply(400, {'message': 'Unknown category'}),
      );
      await expectLater(
        server.run(() => catalog.menuItems(lat: 0, lng: 0)),
        throwsA(
          isA<Exception>().having((e) => '$e', 'text', contains('Unknown')),
        ),
      );
    });
  });
}
