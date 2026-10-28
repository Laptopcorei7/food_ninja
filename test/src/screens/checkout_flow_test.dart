import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/screens/add_card_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

const _longPlace = 'The Golden Spoon Kitchen and Grill House, Ayeduase Road';
const _longStreet =
    'Plot 14 Behind the Old Presbyterian Church, Ayeduase New Site, Kumasi';

Map<String, dynamic> _ok(Object data) => {'success': true, 'data': data};

/// A server with a two-restaurant cart, saved addresses and payment
/// methods. It answers checkout calls the way the real one does.
class _CheckoutServer {
  _CheckoutServer({
    this.methods = const [
      {'_id': 'p0', 'type': 'card', 'brand': null, 'last4': null},
      {'_id': 'p1', 'type': 'card', 'brand': 'visa', 'last4': '4242'},
    ],
    this.long = false,
    this.placeStatus = 200,
  }) {
    server = FakeServer(_handle);
  }

  late final FakeServer server;
  final List<Map<String, dynamic>> methods;
  final bool long;
  int placeStatus;

  Map<String, dynamic> get _cart => {
        'orders': [
          {
            '_id': 'o1',
            'subTotal': 90,
            'deliveryCharge': 10,
            'items': [
              {
                '_id': 'l1',
                'name': 'Jollof Rice',
                'restaurantName': long ? _longPlace : 'Buka Place',
                'qty': 2,
                'price': 45,
                'optionName': 'Large',
              },
            ],
          },
          {
            '_id': 'o2',
            'subTotal': 20,
            'deliveryCharge': 10,
            'items': [
              {
                '_id': 'l3',
                'name': 'Kelewele',
                'restaurantName': 'Chop Bar',
                'qty': 1,
                'price': 20,
              },
            ],
          },
        ],
        'cartCount': 3,
        'summary': {
          'subTotal': 110,
          'deliveryCharge': 20,
          'discount': 0,
          'total': 130,
        },
      };

  Map<String, dynamic> _placed(String id, String restaurant, String status) {
    final at = DateTime.utc(2026, 10, 23, 12);
    return {
      '_id': id,
      'status': status,
      'statusHistory': [
        {'status': 'placed', 'at': at.toIso8601String()},
        if (status == 'accepted')
          {
            'status': 'accepted',
            'at': at.add(const Duration(minutes: 2)).toIso8601String(),
          },
      ],
      'estimatedMinutes': restaurant == 'Chop Bar' ? 25 : 35,
      'total': 80,
      'deliveryAddress': {
        'address': long ? _longStreet : 'Hall 7, KNUST, Kumasi',
        'latitude': 6.67,
        'longitude': -1.57,
      },
      'items': [
        {'_id': 'x', 'name': 'Dish', 'restaurantName': restaurant, 'qty': 1},
      ],
    };
  }

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    final body = request.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    switch ((request.method, path)) {
      case ('GET', 'cart'):
        return FakeServer.reply(200, _ok(_cart));
      case ('POST', 'cart/voucher'):
        if (body['code'] != 'JOLLOF20') {
          return FakeServer.reply(400, {'message': 'Voucher code not found'});
        }
        return FakeServer.reply(
          200,
          _ok({
            'voucher': {'code': 'JOLLOF20', 'title': 'GH₵ 20 off jollof'},
            'summary': {
              'subTotal': 110,
              'deliveryCharge': 20,
              'discount': 20,
              'total': 110,
            },
          }),
        );
      case ('POST', 'cart/place'):
        if (placeStatus != 200) {
          return FakeServer.reply(placeStatus, {
            'message': 'Your cart changed while checking out. Please review '
                'it and try again.',
          });
        }
        return FakeServer.reply(
          200,
          _ok({
            'orders': [
              _placed('o1', long ? _longPlace : 'Buka Place', 'placed'),
              _placed('o2', 'Chop Bar', 'placed'),
            ],
          }),
        );
      case ('GET', 'orders/o1'):
        return FakeServer.reply(
          200,
          _ok(_placed('o1', 'Buka Place', 'accepted')),
        );
      case ('GET', 'orders/o2'):
        return FakeServer.reply(200, _ok(_placed('o2', 'Chop Bar', 'placed')));
      case ('GET', 'users/me/addresses'):
        return FakeServer.reply(
          200,
          _ok({
            'addresses': [
              {
                '_id': 'a1',
                'label': 'Home',
                'address': long ? _longStreet : 'Hall 7, KNUST, Kumasi',
                'latitude': 6.67,
                'longitude': -1.57,
              },
              {
                '_id': 'a2',
                'label': 'Work',
                'address': 'Adum, Kumasi',
                'latitude': 6.69,
                'longitude': -1.62,
              },
            ],
          }),
        );
      case ('GET', 'users/me/payment-methods'):
        return FakeServer.reply(200, _ok({'paymentMethods': methods}));
      case ('POST', 'users/me/payment-methods'):
        return FakeServer.reply(
          201,
          _ok({
            'paymentMethod': {'_id': 'p9', ...body},
          }),
        );
      case ('PATCH', final p) when p.startsWith('users/me/payment-methods/'):
        return FakeServer.reply(
          200,
          _ok({
            'paymentMethod': {
              '_id': p.split('/').last,
              'type': 'card',
              ...body,
            },
          }),
        );
      case ('GET', 'users/me'):
        return FakeServer.reply(200, _ok({'user': <String, dynamic>{}}));
    }
    return FakeServer.reply(404, {'message': 'No route $path'});
  }

  List<http.Request> calls(String method, String path) => [
        for (final r in server.requests)
          if (r.method == method && r.url.path == '/api/v1/$path') r,
      ];
}

/// Opens checkout from a plain page, as the cart's button does.
Future<void> _openCheckout(
  WidgetTester tester,
  _CheckoutServer s, {
  bool dark = false,
  bool small = false,
}) {
  if (small) {
    tester.useSmallPhone();
  } else {
    tester.view.physicalSize = const Size(400 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  return s.server.run(() async {
    await tester.pumpApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.checkout),
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

Future<void> _tapAndSettle(
  WidgetTester tester,
  _CheckoutServer s,
  Finder finder,
) =>
    s.server.run(() async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    });

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().logout();
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    CatalogService.cartCount.value = null;
    // GPS off: checkout falls back to the first saved address.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'isLocationServiceEnabled' ? false : null,
    );
  });

  group('card and wallet checks', () {
    test('the brand comes from the first digits', () {
      expect(cardBrand('4242 4242'), 'visa');
      expect(cardBrand('5555'), 'mastercard');
      expect(cardBrand('2221 0000'), 'mastercard');
      expect(cardBrand('2720'), 'mastercard');
      expect(cardBrand('3782 8224'), isNull);
      expect(cardBrand(''), isNull);
    });

    test('card numbers pass the Luhn check', () {
      expect(cardNumberValid('4242 4242 4242 4242'), isTrue);
      expect(cardNumberValid('5555 5555 5555 4444'), isTrue);
      expect(cardNumberValid('4242 4242 4242 4241'), isFalse);
      expect(cardNumberValid('4242'), isFalse);
    });

    test('an expiry must be MM/YY and not in the past', () {
      final now = DateTime(2026, 10, 23);
      expect(expiryValid('10/26', now: now), isTrue);
      expect(expiryValid('01/30', now: now), isTrue);
      expect(expiryValid('09/26', now: now), isFalse);
      expect(expiryValid('13/27', now: now), isFalse);
      expect(expiryValid('1027', now: now), isFalse);
    });

    test('the network comes from the number prefix', () {
      expect(momoNetwork('0241234567'), 'mtn');
      expect(momoNetwork('+233 55 123 4567'), 'mtn');
      expect(momoNetwork('0501234567'), 'telecel');
      expect(momoNetwork('0271234567'), 'airteltigo');
      expect(momoNetwork('0311234567'), isNull);
    });

    test('payment methods name themselves', () {
      PaymentMethod m(Map<String, dynamic> json) =>
          PaymentMethod.fromJson({'_id': 'x', ...json});
      expect(
        m({'type': 'card', 'brand': 'visa', 'last4': '4242'}).name,
        'Visa',
      );
      expect(
        m({'type': 'card', 'brand': 'visa', 'last4': '4242'}).masked,
        '•••• 4242',
      );
      expect(m({'type': 'card'}).needsDetails, isTrue);
      expect(m({'type': 'momo', 'network': 'mtn'}).name, 'MTN MoMo');
      expect(m({'type': 'paypal'}).needsDetails, isFalse);
      expect(PaymentMethod.cash.name, 'Cash on delivery');
    });
  });

  testWidgets(
      'checkout shows the saved address, the first ready card, the orders '
      'and the totals', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    expect(find.text('Hall 7, KNUST, Kumasi'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    // p0 has no number yet, so p1 is chosen.
    expect(find.text('Visa'), findsOneWidget);
    expect(find.text('•••• 4242'), findsOneWidget);
    expect(find.text('Buka Place'), findsOneWidget);
    expect(find.text('Jollof Rice (Large)'), findsOneWidget);
    expect(find.text('Delivery (2 restaurants)'), findsOneWidget);
    expect(find.text('GH₵ 130'), findsOneWidget);
  });

  testWidgets('a voucher takes its discount off the total', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    await s.server.run(() async {
      await tester.enterText(find.byType(TextField), 'nope');
    });
    await _tapAndSettle(tester, s, find.text('Apply'));
    expect(find.text('Voucher code not found'), findsOneWidget);

    await s.server.run(() async {
      await tester.enterText(find.byType(TextField), 'JOLLOF20');
    });
    await _tapAndSettle(tester, s, find.text('Apply'));
    expect(find.text('JOLLOF20'), findsOneWidget);
    expect(find.text('− GH₵ 20'), findsOneWidget);
    expect(find.text('GH₵ 110'), findsWidgets);
    expect(find.text('Voucher code not found'), findsNothing);
  });

  testWidgets(
      'placing sends the address, card and voucher, then shows the '
      'confirmation and the delivery steps', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    await s.server.run(() async {
      await tester.enterText(find.byType(TextField), 'JOLLOF20');
    });
    await _tapAndSettle(tester, s, find.text('Apply'));
    await _tapAndSettle(tester, s, find.text('Place order'));

    final place = s.calls('POST', 'cart/place').single;
    expect(jsonDecode(place.body), {
      'deliveryAddress': {
        'address': 'Hall 7, KNUST, Kumasi',
        'latitude': 6.67,
        'longitude': -1.57,
      },
      'paymentMethodId': 'p1',
      'voucherCode': 'JOLLOF20',
    });
    expect(CatalogService.cartCount.value, 0);
    expect(find.text('Order confirmed!'), findsOneWidget);
    expect(find.textContaining('Your 2 orders have been placed'), findsOne);
    expect(find.textContaining('Arriving by about'), findsOneWidget);

    await _tapAndSettle(tester, s, find.text('Track my order'));
    expect(find.text('Delivery time'), findsOneWidget);
    expect(find.text('35 mins'), findsOneWidget);
    expect(find.text('25 mins'), findsOneWidget);
    expect(find.text('Order placed'), findsNWidgets(2));

    // Pulling down asks the server for each order again.
    await s.server.run(() async {
      await tester.fling(
        find.text('Delivery address'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
    });
    expect(s.calls('GET', 'orders/o1'), hasLength(1));
    expect(find.text('The restaurant accepted your order'), findsNWidgets(2));

    // Back from the confirmation goes past checkout and the cart.
    await _tapAndSettle(tester, s, find.text('Return home'));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('with no saved card, checkout pays cash', (tester) async {
    final s = _CheckoutServer(methods: const []);
    await _openCheckout(tester, s);
    expect(find.text('Cash on delivery'), findsOneWidget);
    expect(find.text('Pay the rider when your food arrives.'), findsOneWidget);
    await _tapAndSettle(tester, s, find.text('Place order'));
    final body = jsonDecode(s.calls('POST', 'cart/place').single.body) as Map;
    expect(body['paymentType'], 'cash');
    expect(body.containsKey('paymentMethodId'), isFalse);
  });

  testWidgets('a refused order stays on checkout and says why', (tester) async {
    final s = _CheckoutServer(placeStatus: 409);
    await _openCheckout(tester, s);
    await _tapAndSettle(tester, s, find.text('Place order'));
    expect(find.textContaining('Your cart changed'), findsOneWidget);
    expect(find.text('Place order'), findsOneWidget);
    // The cart is read again to show what changed.
    expect(s.calls('GET', 'cart'), hasLength(2));
  });

  testWidgets('changing the address picks a saved one', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    await _tapAndSettle(tester, s, find.text('Change').first);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Location is off or not allowed'), findsOneWidget);
    await _tapAndSettle(tester, s, find.text('Work'));
    expect(find.text('Adum, Kumasi'), findsOneWidget);
    await _tapAndSettle(tester, s, find.text('Place order'));
    final body = jsonDecode(s.calls('POST', 'cart/place').single.body) as Map;
    expect((body['deliveryAddress'] as Map)['address'], 'Adum, Kumasi');
  });

  testWidgets(
      'a sign-up card without a number asks for it, and only the brand and '
      'last 4 digits are sent', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    await _tapAndSettle(tester, s, find.text('Change').last);
    expect(find.text('Add your card number'), findsOneWidget);
    await _tapAndSettle(tester, s, find.text('Bank card'));
    expect(find.text('Save card'), findsOneWidget);

    await s.server.run(() async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ama Mensah');
      await tester.enterText(fields.at(1), '5555555555554444');
      await tester.enterText(fields.at(2), '1230');
      await tester.pump();
    });
    expect(find.text('5555 5555 5555 4444'), findsNWidgets(2));
    expect(find.text('12/30'), findsNWidgets(2));
    await _tapAndSettle(tester, s, find.text('Save card'));

    final patch = s.calls('PATCH', 'users/me/payment-methods/p0').single;
    expect(jsonDecode(patch.body), {'brand': 'mastercard', 'last4': '4444'});
    expect(find.text('Mastercard'), findsOneWidget);
    expect(find.text('•••• 4444'), findsOneWidget);
  });

  testWidgets('a bad card number is caught before saving', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    await _tapAndSettle(tester, s, find.text('Change').last);
    await _tapAndSettle(tester, s, find.text('Add card'));
    await s.server.run(() async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ama Mensah');
      await tester.enterText(fields.at(1), '3782 8224 6310 005');
      await tester.enterText(fields.at(2), '1230');
    });
    await _tapAndSettle(tester, s, find.text('Save card'));
    expect(find.text('We take Visa and Mastercard.'), findsOneWidget);
    expect(s.calls('POST', 'users/me/payment-methods'), isEmpty);
  });

  testWidgets('mobile money picks the network from the number', (tester) async {
    final s = _CheckoutServer();
    await _openCheckout(tester, s);
    await _tapAndSettle(tester, s, find.text('Change').last);
    await _tapAndSettle(tester, s, find.text('Add mobile money'));
    await s.server.run(() async {
      await tester.enterText(find.byType(TextField), '0501234567');
      await tester.pump();
    });
    await _tapAndSettle(tester, s, find.text('Save'));
    final post = s.calls('POST', 'users/me/payment-methods').single;
    expect(jsonDecode(post.body), {
      'type': 'momo',
      'network': 'telecel',
      'last4': '4567',
    });
    expect(find.text('Telecel Cash'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('long names fit a small phone (${dark ? 'dark' : 'light'})',
        (tester) async {
      final s = _CheckoutServer(long: true);
      await _openCheckout(tester, s, small: true, dark: dark);
      expect(tester.takeException(), isNull);
      await _tapAndSettle(tester, s, find.text('Place order'));
      expect(tester.takeException(), isNull);
      await _tapAndSettle(tester, s, find.text('Track my order'));
      expect(tester.takeException(), isNull);
      expect(find.text(_longPlace), findsOneWidget);
    });
  }
}
