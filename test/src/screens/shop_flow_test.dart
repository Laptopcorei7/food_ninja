import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/screens/filter_screen.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/screens/onboarding_screen.dart';
import 'package:food_ninja/src/screens/restaurant_screen.dart';
import 'package:food_ninja/src/screens/search_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

const _here = Here(lat: 6.67, lng: -1.57, area: 'Ayeduase', fromGps: false);

Map<String, dynamic> _dish(String id, String name, {String? category}) => {
      '_id': id,
      'name': name,
      'price': 40,
      'rating': 4.5,
      'description': 'Served hot',
      'category': category ?? 'rice',
      'restaurant': {'_id': 'r1', 'name': 'Buka Place'},
      'distanceKm': 1.2,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
      'success': true,
      'data': {
        'items': items,
        'page': 1,
        'totalPages': 1,
        'priceRange': {'min': 5, 'max': 200},
      },
    };

/// The server as the app sees it after sign-up: one restaurant, a few
/// dishes and one offer. [expired] answers 401 to everything.
FakeServer _server({bool expired = false}) => FakeServer((request) async {
      if (expired) return FakeServer.reply(401);
      final path = request.url.path.replaceFirst('/api/v1/', '');
      return switch (path) {
        'users/me' => FakeServer.reply(200, {
            'success': true,
            'data': {
              'user': {
                'firstName': 'Ama',
                'lastName': 'Mensah',
                'email': 'ama@b.co',
                'location': {
                  'address': 'Ayeduase, Kumasi',
                  'latitude': 6.67,
                  'longitude': -1.57,
                },
              },
            },
          }),
        // Kebab is also top rated, so Recommend must leave it out.
        'menu-items/for-you' => FakeServer.reply(
            200,
            _page([_dish('m2', 'Beef Kebab', category: 'grills')]),
          ),
        'menu-items' => FakeServer.reply(
            200,
            _page([
              _dish('m1', 'Jollof Rice'),
              _dish('m2', 'Beef Kebab', category: 'grills'),
            ]),
          ),
        'restaurants' => FakeServer.reply(
            200,
            _page([
              {
                '_id': 'r1',
                'name': 'Buka Place',
                'rating': 4.4,
                'distanceKm': 1.2,
                'deliveryTimeMins': 25,
              },
            ]),
          ),
        'vouchers' => FakeServer.reply(200, {
            'success': true,
            'data': [
              {'_id': 'v1', 'title': 'Jollof Friday', 'discountAmount': 10},
            ],
          }),
        'restaurants/r1' => FakeServer.reply(200, {
            'success': true,
            'data': {
              '_id': 'r1',
              'name': 'Buka Place',
              'rating': 4.4,
              'address': 'Ayeduase Road',
              'distanceKm': 1.2,
            },
          }),
        'restaurants/r1/menu' => FakeServer.reply(200, {
            'success': true,
            'data': [
              {'_id': 'm1', 'name': 'Jollof Rice', 'category': 'rice'},
              {'_id': 'm2', 'name': 'Beef Kebab', 'category': 'grills'},
            ],
          }),
        _ => FakeServer.reply(404),
      };
    });

/// The screen's vertical list (the category and dish strips scroll
/// sideways inside it).
Finder _vertical([Finder? within]) => find
    .descendant(
      of: within ?? find.byType(Scaffold).last,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

List<http.Request> _calls(FakeServer s, String path) => [
      for (final r in s.requests)
        if (r.url.path == '/api/v1/$path') r,
    ];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().logout();
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    // Location off: an unanswered platform call would never return in a
    // widget test, and this way Home uses the saved sign-up address.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'isLocationServiceEnabled' ? false : null,
    );
  });

  test('the greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 7)).$1, 'Good Morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)).$1, 'Good Afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 19)).$1, 'Good Evening');
    expect(greetingFor(DateTime(2026, 1, 1, 2)).$1, 'Still Up?');
  });

  testWidgets(
      'Home shows categories, best sellers, offers, places and '
      'recommendations', (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
    });
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Best Seller'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Jollof Friday'),
      200,
      scrollable: _vertical(),
    );
    expect(find.text('Jollof Friday'), findsOneWidget);
    expect(find.text('GH₵ 10 OFF'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Near You'),
      200,
      scrollable: _vertical(),
    );
    expect(find.text('Near You'), findsOneWidget);
    expect(find.text('Buka Place'), findsWidgets);
    // Every dish says where it comes from.
    expect(find.text('Jollof Rice'), findsWidgets);
    // The saved address stands in for GPS, which tests don't have.
    final q = _calls(server, 'menu-items').first.url.queryParameters;
    expect(q['lat'], '6.67');
    expect(q['maxKm'], '$deliveryRangeKm');
  });

  testWidgets('a category on Home opens Menu filtered to it', (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Grills').first);
      await tester.pumpAndSettle();
    });
    expect(find.text('Sort by'), findsOneWidget);
    expect(
      _calls(server, 'menu-items').last.url.queryParameters['category'],
      'grills',
    );
  });

  testWidgets('For You comes first and Recommend skips its dishes',
      (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
    });
    expect(find.text('For You'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('For You')).dy,
      lessThan(tester.getTopLeft(find.text('Best Seller')).dy),
    );
    await tester.scrollUntilVisible(
      find.text('Recommend'),
      200,
      scrollable: _vertical(),
    );
    await tester.pumpAndSettle();
    // The grid under Recommend has Jollof but not the Kebab For You shows.
    final grid = find.byType(DishGrid);
    expect(
      find.descendant(of: grid, matching: find.text('Jollof Rice')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: grid, matching: find.text('Beef Kebab')),
      findsNothing,
    );
  });

  testWidgets('Home and Menu both have the icon buttons, Menu says where',
      (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.text('Search'), findsNothing);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
    });
    // Only the Menu tab is on stage, so each button is found once.
    expect(find.text('Menu'), findsOneWidget);
    expect(find.textContaining('Dishes near'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Cart'), findsOneWidget);
  });

  testWidgets('changing the sort reloads the menu', (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top rated').last);
      await tester.pumpAndSettle();
    });
    expect(
      _calls(server, 'menu-items').last.url.queryParameters['sort'],
      'rating',
    );
  });

  testWidgets('Filter returns the chosen rating and distance', (tester) async {
    final server = _server();
    MenuFilter? result;
    await server.run(() async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<MenuFilter>(
                  builder: (_) => const FilterScreen(
                    args: FilterArgs(filter: MenuFilter(), here: _here),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 stars and up'));
      await tester.tap(find.text('Under 5 km'));
      await tester.pumpAndSettle();
      // The price slider appears once the server sends the price range.
      await tester.scrollUntilVisible(
        find.text('Any price'),
        100,
        scrollable: _vertical(),
      );
      expect(find.byType(Slider, skipOffstage: false), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Apply'),
        100,
        scrollable: _vertical(),
      );
      await tester.ensureVisible(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
    });
    expect(result?.minRating, 4);
    expect(result?.maxKm, 5);
    expect(result?.maxPrice, isNull);
  });

  testWidgets('the profile drawer shows the user and logs out', (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile and settings'));
      await tester.pumpAndSettle();
      expect(find.text('Ama Mensah'), findsOneWidget);
      expect(find.text('ama@b.co'), findsOneWidget);
      // Below the edge of the default 800 x 600 test screen.
      await tester.ensureVisible(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, log out'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(await AuthService().getToken(), isNull);
  });

  testWidgets('an expired login on Home goes back to welcome', (tester) async {
    final server = _server(expired: true);
    await server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
    });
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('a restaurant page lists its menu by category', (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const RestaurantScreen(id: 'r1', here: _here));
      await tester.pumpAndSettle();
    });
    expect(find.text('Buka Place'), findsOneWidget);
    expect(find.text('Ayeduase Road'), findsOneWidget);
    for (final heading in ['Rice dishes', 'Grills']) {
      await tester.scrollUntilVisible(
        find.text(heading),
        200,
        scrollable: _vertical(),
      );
      expect(find.text(heading), findsOneWidget);
    }
    expect(
      _calls(server, 'restaurants/r1').single.url.queryParameters['lng'],
      '-1.57',
    );
  });

  testWidgets('a filter on the search page searches dishes on its own',
      (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const SearchScreen(here: _here));
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Under 2 km'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Apply'),
        100,
        scrollable: _vertical(),
      );
      await tester.ensureVisible(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
    });
    expect(find.byTooltip('Filter, on'), findsOneWidget);
    expect(find.text('Dishes'), findsOneWidget);
    // Nothing typed: restaurants (name search only) are not asked for.
    expect(_calls(server, 'restaurants'), isEmpty);
    expect(
      _calls(server, 'menu-items').last.url.queryParameters['maxKm'],
      '2.0',
    );
  });

  testWidgets('search waits for a pause in typing, then shows both lists',
      (tester) async {
    final server = _server();
    await server.run(() async {
      await tester.pumpApp(const SearchScreen(here: _here));
      await tester.enterText(find.byType(TextField), 'jol');
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Dishes'), findsOneWidget);
    expect(
      _calls(server, 'menu-items').single.url.queryParameters['search'],
      'jol',
    );
  });

  // Every step-3 screen must fit a 360 x 640 phone, in both themes.
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final screens = <String, Widget>{
      'home': const HomeScreen(),
      'restaurant': const RestaurantScreen(id: 'r1', here: _here),
      'filter': const FilterScreen(
        args: FilterArgs(filter: MenuFilter(), here: _here),
      ),
    };
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets('$name fits a small phone ($mode)', (tester) async {
        tester.useSmallPhone();
        await _server().run(() async {
          await tester.pumpApp(screen, dark: dark);
          await tester.pumpAndSettle();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the menu tab fits a small phone', (tester) async {
    tester.useSmallPhone();
    await _server().run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
    });
    expect(tester.takeException(), isNull);
  });
}
