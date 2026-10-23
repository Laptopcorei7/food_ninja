import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/cart_screen.dart';
import 'package:food_ninja/src/screens/home_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

const _longDish =
    'Extra Large Pepperoni and Three Cheese Pizza with Grilled Peppers';
const _longPlace = 'The Golden Spoon Kitchen and Grill House, Ayeduase Road';

Map<String, dynamic> _line(
  String id,
  String name,
  int qty,
  double price,
  String restaurant, {
  String? option,
}) =>
    {
      '_id': id,
      'menuItemId': 'm$id',
      'name': name,
      'restaurantName': restaurant,
      'qty': qty,
      'price': price,
      if (option != null) 'optionName': option,
    };

/// A server holding a cart of two restaurants. PUT and DELETE on a line
/// change it, and GET /cart sums it the way the server does.
class _CartServer {
  _CartServer({bool long = false, this.empty = false, this.status = 200}) {
    orders = [
      {
        '_id': 'o1',
        'items': [
          _line(
            'l1',
            long ? _longDish : 'Jollof Rice',
            2,
            45,
            long ? _longPlace : 'Buka Place',
            option: long ? 'Family size, twelve slices' : 'Large',
          ),
          _line('l2', 'Sobolo', 1, 10, 'Buka Place'),
        ],
      },
      {
        '_id': 'o2',
        'items': [_line('l3', 'Kelewele', 1, 20, 'Chop Bar')],
      },
    ];
    server = FakeServer(_handle);
  }

  late final FakeServer server;
  late List<Map<String, dynamic>> orders;
  final bool empty;
  int status;

  /// An order's lines, typed; changes go through to the order.
  static List<Map<String, dynamic>> _items(Map<String, dynamic> order) =>
      (order['items'] as List).cast();

  Map<String, dynamic> _cart() {
    final list = empty ? <Map<String, dynamic>>[] : orders;
    double sub(Map<String, dynamic> o) => [
          for (final l in _items(o)) (l['price'] as num) * (l['qty'] as num),
        ].fold(0, (a, b) => a + b);
    final subTotal = list.fold<double>(0, (a, o) => a + sub(o));
    final count = list.fold<int>(
      0,
      (a, o) => a + _items(o).fold<int>(0, (b, l) => b + (l['qty'] as int)),
    );
    final delivery = 10.0 * list.length;
    return {
      'orders': [
        for (final o in list) {...o, 'subTotal': sub(o), 'deliveryCharge': 10},
      ],
      'cartCount': count,
      'summary': {
        'subTotal': subTotal,
        'deliveryCharge': delivery,
        'discount': 0,
        'total': subTotal + delivery,
      },
    };
  }

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    if (status != 200) {
      return FakeServer.reply(status, {'message': 'Server said no.'});
    }
    final line = RegExp(r'^orders/(\w+)/items/(\w+)$').firstMatch(path);
    if (line != null) {
      final order = orders.firstWhere((o) => o['_id'] == line[1]);
      final items = _items(order);
      if (request.method == 'DELETE') {
        items.removeWhere((l) => l['_id'] == line[2]);
        orders.removeWhere((o) => _items(o).isEmpty);
      } else {
        final qty = (jsonDecode(request.body) as Map)['qty'];
        items.firstWhere((l) => l['_id'] == line[2])['qty'] = qty;
      }
      return FakeServer.reply(200, {
        'success': true,
        'data': <String, dynamic>{},
      });
    }
    return switch (path) {
      'cart' => FakeServer.reply(200, {'success': true, 'data': _cart()}),
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
  }

  List<http.Request> calls(String path) => [
        for (final r in server.requests)
          if (r.url.path == '/api/v1/$path') r,
      ];
}

/// Opens the cart from a plain page, as Home's cart button does.
Future<void> _openCart(
  WidgetTester tester,
  _CartServer s, {
  bool dark = false,
  bool small = false,
}) {
  if (small) {
    tester.useSmallPhone();
  } else {
    tester.view.physicalSize = const Size(400 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  return s.server.run(() async {
    await tester.pumpApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.cart),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      dark: dark,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  });
}

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

  test('a cart reads its orders, lines and the server totals', () {
    final cart = Cart.fromJson(_CartServer()._cart());
    expect(cart.orders, hasLength(2));
    expect(cart.orders.first.restaurantName, 'Buka Place');
    expect(cart.orders.first.lines.first.optionName, 'Large');
    expect(cart.count, 4);
    expect(cart.total, 140);
    // An old server without a summary still parses.
    expect(Cart.fromJson(const {'orders': <Object>[]}).isEmpty, isTrue);
  });

  testWidgets('the cart groups dishes by restaurant and shows the totals',
      (tester) async {
    final s = _CartServer();
    await _openCart(tester, s);
    expect(find.text('You have 4 items in your cart'), findsOneWidget);
    expect(find.text('Buka Place'), findsOneWidget);
    expect(find.text('Chop Bar'), findsOneWidget);
    expect(find.text('Large · GH₵ 45'), findsOneWidget);
    expect(find.text('GH₵ 90'), findsOneWidget);
    expect(find.text('Delivery (2 restaurants)'), findsOneWidget);
    expect(find.text('GH₵ 120'), findsOneWidget);
    expect(find.text('GH₵ 140'), findsOneWidget);
    expect(CatalogService.cartCount.value, 4);
  });

  testWidgets(
      'quick taps change the number and totals at once and send one '
      'request', (tester) async {
    final s = _CartServer();
    await _openCart(tester, s);
    await s.server.run(() async {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('One more Kelewele'));
        await tester.pump();
      }
    });
    // Shown before the server hears anything.
    expect(s.calls('orders/o2/items/l3'), isEmpty);
    expect(find.text('You have 7 items in your cart'), findsOneWidget);
    expect(find.text('GH₵ 80'), findsOneWidget);
    expect(find.text('GH₵ 200'), findsOneWidget);
    expect(CatalogService.cartCount.value, 7);
    expect(find.text('Saving…'), findsOneWidget);

    await s.server.run(() async {
      await tester.pump(CartScreen.syncDelay);
      await tester.pumpAndSettle();
    });
    final put = s.calls('orders/o2/items/l3').single;
    expect(put.method, 'PUT');
    expect(jsonDecode(put.body), {'qty': 4});
    expect(find.text('Checkout'), findsOneWidget);
    expect(CatalogService.cartCount.value, 7);
  });

  testWidgets('− lowers the quantity', (tester) async {
    final s = _CartServer();
    await _openCart(tester, s);
    await s.server.run(() async {
      await tester.tap(find.byTooltip('One less Jollof Rice'));
      await tester.pump(CartScreen.syncDelay);
      await tester.pumpAndSettle();
    });
    expect(jsonDecode(s.calls('orders/o1/items/l1').single.body), {'qty': 1});
  });

  testWidgets('leaving before the change is sent still saves it',
      (tester) async {
    final s = _CartServer();
    await _openCart(tester, s);
    await s.server.run(() async {
      await tester.tap(find.byTooltip('One more Kelewele'));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
    });
    expect(find.byType(CartScreen), findsNothing);
    expect(jsonDecode(s.calls('orders/o2/items/l3').single.body), {'qty': 2});
  });

  testWidgets('at one, the bin takes the dish out', (tester) async {
    final s = _CartServer();
    await _openCart(tester, s);
    expect(find.byTooltip('One less Kelewele'), findsNothing);
    await s.server.run(() async {
      await tester.tap(find.byTooltip('Remove Kelewele'));
      await tester.pumpAndSettle();
    });
    expect(s.calls('orders/o2/items/l3').single.method, 'DELETE');
    expect(find.text('Chop Bar'), findsNothing);
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('a refused change goes back and says why', (tester) async {
    final s = _CartServer();
    await _openCart(tester, s);
    s.status = 500;
    await s.server.run(() async {
      await tester.tap(find.byTooltip('One more Kelewele'));
      await tester.pump(CartScreen.syncDelay);
      await tester.pumpAndSettle();
    });
    expect(find.text('Server said no.'), findsOneWidget);
    expect(find.text('You have 4 items in your cart'), findsOneWidget);
    expect(CatalogService.cartCount.value, 4);
  });

  testWidgets('an empty cart invites adding something, which goes back',
      (tester) async {
    final s = _CartServer(empty: true);
    await _openCart(tester, s);
    expect(find.text('Your cart is empty'), findsOneWidget);
    await tester.tap(find.text('Want to add something?'));
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsNothing);
  });

  testWidgets('a cart that fails to load offers a retry', (tester) async {
    final s = _CartServer(status: 500);
    await _openCart(tester, s);
    expect(find.text('Server said no.'), findsOneWidget);
    s.status = 200;
    await s.server.run(() async {
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
    });
    expect(find.text('You have 4 items in your cart'), findsOneWidget);
  });

  testWidgets('an expired login goes back to welcome', (tester) async {
    await _openCart(tester, _CartServer(status: 401));
    expect(find.byType(CartScreen), findsNothing);
    expect(await AuthService().getToken(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('long names fit a small phone (${dark ? 'dark' : 'light'})',
        (tester) async {
      final s = _CartServer(long: true);
      await _openCart(tester, s, dark: dark, small: true);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Total'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Checkout'), findsOneWidget);
    });
  }

  testWidgets("Home's cart button opens the cart page", (tester) async {
    final s = _CartServer();
    await s.server.run(() async {
      await tester.pumpApp(const HomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cart, 4 items'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
  });
}
