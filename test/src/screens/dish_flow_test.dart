import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/screens/dish_screen.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/widgets/catalog_cards.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

const _here = Here(lat: 6.67, lng: -1.57, area: 'Ayeduase', fromGps: false);

const _longName =
    'Extra Large Pepperoni and Three Cheese Pizza with Grilled Peppers';

Map<String, dynamic> _pizza({String name = 'Pepperoni Pizza'}) => {
      '_id': 'm1',
      'name': name,
      'price': 80,
      'rating': 4.6,
      'description': 'Stone-baked with mozzarella.',
      'ingredients': ['dough', 'pepperoni', 'mozzarella'],
      'category': 'pizza-burgers',
      'restaurant': {'_id': 'r1', 'name': 'Buka Place'},
      'distanceKm': 1.2,
      'options': [
        {'_id': 'o1', 'name': 'Small', 'extraPrice': 0},
        {'_id': 'o2', 'name': 'Medium', 'extraPrice': 25},
        {
          '_id': 'o3',
          'name': name == _longName ? 'Family size, twelve slices' : 'Large',
          'extraPrice': 50,
        },
      ],
      'isFavorite': false,
    };

/// What the lists hand the dish page before it loads its own copy.
final _listItem = MenuItem.fromJson(_pizza()..remove('options'));

/// The phase 4 server: one dish, the cart and favourites. [status] answers
/// every call that isn't GET /menu-items/m1 or the menu list.
FakeServer _server({
  String name = 'Pepperoni Pizza',
  int status = 200,
  bool dishFails = false,
  List<Map<String, dynamic>> favorites = const [],
}) =>
    FakeServer((request) async {
      final path = request.url.path.replaceFirst('/api/v1/', '');
      if (path == 'menu-items/m1') {
        return dishFails
            ? FakeServer.reply(500, {'message': "Couldn't load the dish."})
            : FakeServer.reply(
                200,
                {'success': true, 'data': _pizza(name: name)},
              );
      }
      if (status != 200) {
        return FakeServer.reply(status, {'message': 'Server said no.'});
      }
      return switch (path) {
        'cart/items' => FakeServer.reply(200, {
            'success': true,
            'data': {'order': <String, dynamic>{}, 'cartCount': 3},
          }),
        'cart' => FakeServer.reply(200, {
            'success': true,
            'data': {'orders': <Object>[], 'cartCount': 5},
          }),
        'users/me/favorites' => FakeServer.reply(200, {
            'success': true,
            'data': {'items': favorites, 'page': 1, 'totalPages': 1},
          }),
        'users/me/favorites/m1' => FakeServer.reply(200, {
            'success': true,
            'data': {
              'favoriteMenuItems': ['m1'],
            },
          }),
        'menu-items' => FakeServer.reply(200, {
            'success': true,
            'data': {
              'items': [_pizza()],
              'page': 1,
              'totalPages': 1,
            },
          }),
        'users/me' => FakeServer.reply(200, {
            'success': true,
            'data': {
              'user': {
                'firstName': 'Ama',
                'location': {
                  'address': 'Ayeduase, Kumasi',
                  'latitude': 6.67,
                  'longitude': -1.57,
                },
              },
            },
          }),
        _ => FakeServer.reply(200, {
            'success': true,
            'data': {'items': <Object>[], 'page': 1, 'totalPages': 1},
          }),
      };
    });

List<http.Request> _calls(FakeServer s, String path) => [
      for (final r in s.requests)
        if (r.url.path == '/api/v1/$path') r,
    ];

/// Shows the dish page. Unless [small], on a tall screen so the whole page
/// is built without scrolling.
Future<void> _showDish(
  WidgetTester tester,
  FakeServer server, {
  bool dark = false,
  bool small = false,
  MenuItem? item,
}) {
  if (small) {
    tester.useSmallPhone();
  } else {
    tester.view.physicalSize = const Size(400 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  return server.run(() async {
    await tester.pumpApp(
      DishScreen(item: item ?? _listItem, here: _here),
      dark: dark,
    );
    await tester.pumpAndSettle();
  });
}

Finder get _list => find.byType(Scrollable).first;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().logout();
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    CatalogService.cartCount.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'isLocationServiceEnabled' ? false : null,
    );
  });

  test('a dish reads its portions, ingredients and heart', () {
    final dish = MenuItem.fromJson(_pizza()..['isFavorite'] = true);
    expect(dish.options.map((o) => o.name), ['Small', 'Medium', 'Large']);
    expect(dish.options[1].extraPrice, 25);
    expect(dish.ingredients, hasLength(3));
    expect(dish.isFavorite, isTrue);
    // List items without the new fields still parse.
    final plain = MenuItem.fromJson(const {'_id': 'x', 'name': 'Water'});
    expect(plain.options, isEmpty);
    expect(plain.isFavorite, isFalse);
  });

  testWidgets('the dish page loads its own copy with the user location',
      (tester) async {
    final server = _server();
    await _showDish(tester, server);
    expect(find.text('Pepperoni Pizza'), findsOneWidget);
    expect(find.text('from Buka Place · 1.2 km'), findsOneWidget);
    expect(find.text('GH₵ 80'), findsOneWidget);
    expect(find.text('dough, pepperoni, mozzarella'), findsOneWidget);
    final q = _calls(server, 'menu-items/m1').single.url.queryParameters;
    expect(q['lat'], '6.67');
    expect(q['lng'], '-1.57');
  });

  testWidgets(
      'portion and quantity set the price, and Add to Cart sends them '
      'and updates the badge', (tester) async {
    final server = _server();
    await _showDish(tester, server);
    // The first portion is picked to start with.
    expect(find.text('Add to Cart · GH₵ 80'), findsOneWidget);

    await server.run(() async {
      await tester.scrollUntilVisible(
        find.text('Large'),
        200,
        scrollable: _list,
      );
      await tester.tap(find.text('Large'));
      await tester.pump();
      await tester.tap(find.byTooltip('One more'));
      await tester.pump();
    });
    expect(find.text('GH₵ 130'), findsOneWidget);
    expect(find.text('Add to Cart · GH₵ 260'), findsOneWidget);

    await server.run(() async {
      await tester.scrollUntilVisible(
        find.text('Add to Cart · GH₵ 260'),
        200,
        scrollable: _list,
      );
      await tester.tap(find.text('Add to Cart · GH₵ 260'));
      await tester.pumpAndSettle();
    });
    final sent = jsonDecode(_calls(server, 'cart/items').single.body);
    expect(sent, {'menuItemId': 'm1', 'qty': 2, 'optionId': 'o3'});
    expect(CatalogService.cartCount.value, 3);
    expect(find.text('Added 2 × Pepperoni Pizza to your cart'), findsOneWidget);
  });

  testWidgets('quantity stays between 1 and 99', (tester) async {
    await _showDish(tester, _server());
    final less = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.remove_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(less.onPressed, isNull);
  });

  testWidgets('the heart saves the dish', (tester) async {
    final ok = _server();
    await _showDish(tester, ok);
    await ok.run(() async {
      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
    });
    expect(_calls(ok, 'users/me/favorites/m1').single.method, 'PUT');
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });

  testWidgets('the heart goes back when the server fails', (tester) async {
    final failing = _server(status: 500);
    await _showDish(tester, failing);
    await failing.run(() async {
      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
    });
    expect(find.byTooltip('Add to favourites'), findsOneWidget);
    expect(find.text('Server said no.'), findsOneWidget);
  });

  testWidgets('a dish that fails to load offers a retry, not the cart',
      (tester) async {
    await _showDish(tester, _server(dishFails: true));
    // The list's copy still shows.
    expect(find.text('Pepperoni Pizza'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Try again'),
      200,
      scrollable: _list,
    );
    expect(find.text("Couldn't load the dish."), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Add to Cart'),
      200,
      scrollable: _list,
    );
    final button = tester.widget<MajorButton>(find.byType(MajorButton));
    expect(button.onPress, isNull);
  });

  testWidgets('an expired login on Add to Cart goes back to welcome',
      (tester) async {
    final server = _server(status: 401);
    await _showDish(tester, server);
    await server.run(() async {
      await tester.scrollUntilVisible(
        find.textContaining('Add to Cart'),
        200,
        scrollable: _list,
      );
      await tester.tap(find.textContaining('Add to Cart'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(DishScreen), findsNothing);
    expect(await AuthService().getToken(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'a long dish name fits a small phone '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      final long = MenuItem.fromJson(_pizza(name: _longName));
      await _showDish(
        tester,
        _server(name: _longName),
        dark: dark,
        small: true,
        item: long,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Add to Cart'),
        200,
        scrollable: _list,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Family size, twelve slices'), findsOneWidget);
    });
  }

  testWidgets(
      'a dish on the Menu tab opens its page, and Home shows the '
      'cart count', (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
    });
    expect(find.byTooltip('Cart, 5 items'), findsOneWidget);
    await server.run(() async {
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      // A DishRow: the Home tab's cards stay built under the Menu tab.
      // Near its top: the row's centre is under the bottom nav.
      await tester.tapAt(
        tester.getTopLeft(find.byType(DishRow).first) + const Offset(40, 40),
      );
      await tester.pumpAndSettle();
    });
    expect(find.byType(DishScreen), findsOneWidget);
  });

  testWidgets('Favorites with nothing saved says how to save a dish',
      (tester) async {
    final empty = _server();
    await empty.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorites'));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('No favourites yet'), findsOneWidget);
  });

  testWidgets('Favorites lists saved dishes', (tester) async {
    final saved = _server(favorites: [_pizza()..['isFavorite'] = true]);
    await saved.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorites'));
      await tester.pumpAndSettle();
    });
    expect(find.text('Pepperoni Pizza'), findsOneWidget);
    expect(
      _calls(saved, 'users/me/favorites').last.url.queryParameters['lat'],
      '6.67',
    );
  });
}
