import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/screens/cancel_order_screen.dart';
import 'package:food_ninja/src/screens/chat_screen.dart';
import 'package:food_ninja/src/screens/order_placed_screen.dart';
import 'package:food_ninja/src/screens/orders_screen.dart';
import 'package:food_ninja/src/screens/review_screen.dart';
import 'package:food_ninja/src/screens/tracking_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/utils/open_link.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

const _longPlace = 'The Golden Spoon Kitchen and Grill House, Ayeduase Road';
const _longDish = 'Assorted Fried Rice with Grilled Chicken and Shito Pepper';

Map<String, dynamic> _ok(Object data) => {'success': true, 'data': data};

Map<String, dynamic> _order(
  String id,
  String status, {
  String restaurant = 'Buka Place',
  bool reviewed = false,
  String paymentType = 'card',
  String dish = 'Jollof Rice',
}) {
  final at = DateTime.utc(2026, 10, 23, 12);
  return {
    '_id': id,
    'status': status,
    'statusHistory': [
      {'status': 'placed', 'at': at.toIso8601String()},
      if (status != 'placed')
        {
          'status': status,
          'at': at.add(const Duration(minutes: 30)).toIso8601String(),
        },
    ],
    'estimatedMinutes': 35,
    'restaurant': {'_id': 'r1', 'name': restaurant},
    'itemCount': 3,
    'reviewed': reviewed,
    'paymentType': paymentType,
    'subTotal': 110,
    'deliveryCharge': 10,
    'discount': 20,
    'total': 100,
    if (status == 'cancelled') 'cancelReason': 'I ordered by mistake',
    'deliveryAddress': {
      'address': 'Hall 7, KNUST, Kumasi',
      'latitude': 6.67,
      'longitude': -1.57,
    },
    'items': [
      {
        '_id': 'l1',
        'menuItemId': 'm1',
        'name': dish,
        'restaurantName': restaurant,
        'qty': 1,
        'price': 45,
        'optionName': 'Large',
      },
      {
        '_id': 'l2',
        'menuItemId': 'm1',
        'name': dish,
        'restaurantName': restaurant,
        'qty': 1,
        'price': 35,
        'optionName': 'Regular',
      },
      {
        '_id': 'l3',
        'menuItemId': 'm2',
        'name': 'Kelewele',
        'restaurantName': restaurant,
        'qty': 1,
        'price': 30,
      },
    ],
  };
}

/// Answers the phase 6 order calls the way the real server does.
class _OrdersServer {
  _OrdersServer({this.long = false, this.cancelStatus = 200}) {
    server = FakeServer(_handle);
  }

  late final FakeServer server;
  final bool long;
  int cancelStatus;

  /// What GET tracking answers, in turn; the last one repeats.
  List<String> trackingStatuses = ['on_the_way'];
  int _tracked = 0;

  String get _place => long ? _longPlace : 'Buka Place';
  String get _dish => long ? _longDish : 'Jollof Rice';

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    switch ((request.method, path)) {
      case ('GET', 'orders'):
        final tab = request.url.queryParameters['tab'];
        final items = switch (tab) {
          'active' => [
              _order('a1', 'placed', restaurant: _place, dish: _dish),
              _order('a2', 'preparing', restaurant: 'Chop Bar'),
            ],
          'completed' => [
              _order('c1', 'delivered', restaurant: _place, dish: _dish),
              _order('c2', 'delivered', restaurant: 'Chop Bar', reviewed: true),
            ],
          _ => [_order('x1', 'cancelled', restaurant: _place, dish: _dish)],
        };
        return FakeServer.reply(
          200,
          _ok({'items': items, 'page': 1, 'totalPages': 1, 'total': 2}),
        );
      case ('POST', 'orders/a1/cancel'):
        if (cancelStatus != 200) {
          return FakeServer.reply(cancelStatus, {
            'message': 'The restaurant has started on this order, so it can '
                'no longer be cancelled',
          });
        }
        return FakeServer.reply(
          200,
          _ok({'order': _order('a1', 'cancelled')}),
        );
      case ('POST', 'orders/c1/reorder'):
        return FakeServer.reply(
          200,
          _ok({
            'cartCount': 4,
            'added': 2,
            'skipped': ['Kelewele'],
          }),
        );
      case ('POST', 'orders/c1/review'):
        return FakeServer.reply(
          200,
          _ok({'order': _order('c1', 'delivered', reviewed: true)}),
        );
      case ('GET', 'orders/a2/tracking'):
        final status =
            trackingStatuses[_tracked.clamp(0, trackingStatuses.length - 1)];
        _tracked++;
        return FakeServer.reply(
          200,
          _ok({
            'status': status,
            'restaurant': {
              'name': 'Chop Bar',
              'latitude': 6.68,
              'longitude': -1.58,
            },
            'destination': {
              'latitude': 6.67,
              'longitude': -1.57,
              'address': 'Hall 7, KNUST, Kumasi',
            },
            'rider': status == 'on_the_way' || status == 'delivered'
                ? {
                    'latitude': 6.675,
                    'longitude': -1.575,
                    'name': 'Kwabena Owusu',
                    'phone': '+233200000000',
                  }
                : null,
            'etaMinutes': status == 'delivered' ? 0 : 6,
            'progress': status == 'delivered' ? 1 : 0.5,
            'route': [
              {'latitude': 6.68, 'longitude': -1.58},
              {'latitude': 6.678, 'longitude': -1.572},
              {'latitude': 6.67, 'longitude': -1.57},
            ],
          }),
        );
      case ('GET', 'orders/a2/chat'):
        return FakeServer.reply(
          200,
          _ok({
            'chat': {
              '_id': 'chat-r',
              'kind': 'rider',
              'orderId': 'a2',
              'riderName': 'Kwabena Owusu',
              'messages': <Object>[],
            },
          }),
        );
      case ('GET', 'chats/chat-r/messages'):
        return FakeServer.reply(200, _ok({'messages': <Object>[]}));
      case ('GET', 'orders/a2'):
        return FakeServer.reply(
          200,
          _ok(_order('a2', 'delivered', restaurant: 'Chop Bar')),
        );
      case ('GET', final p) when p.startsWith('orders/'):
        final id = p.split('/').last;
        return FakeServer.reply(200, _ok(_order(id, 'delivered')));
    }
    return FakeServer.reply(404, {'message': 'No route $path'});
  }

  List<http.Request> calls(String method, String path) => [
        for (final r in server.requests)
          if (r.method == method && r.url.path == '/api/v1/$path') r,
      ];
}

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpOrders(
  WidgetTester tester,
  _OrdersServer s, {
  bool dark = false,
  bool small = false,
}) {
  small ? tester.useSmallPhone() : _tallPhone(tester);
  return s.server.run(() async {
    await tester.pumpApp(const OrdersTab(active: true), dark: dark);
    await tester.pumpAndSettle();
  });
}

Future<void> _tap(WidgetTester tester, _OrdersServer s, Finder finder) =>
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
    LiveTrackingScreen.showTiles = false;
  });

  group('My Orders tab', () {
    testWidgets('Active lists placed orders with cancel only before the '
        'kitchen starts', (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);

      expect(s.calls('GET', 'orders').single.url.queryParameters['tab'],
          'active',);
      expect(find.text('Buka Place'), findsOneWidget);
      expect(find.text('Chop Bar'), findsOneWidget);
      expect(find.text('GH₵ 100'), findsNWidgets(2));
      expect(find.text('3 items'), findsNWidgets(2));
      // a1 is placed (cancellable), a2 is preparing (not).
      expect(find.text('Cancel order'), findsOneWidget);
      expect(find.text('Track'), findsNWidgets(2));
      expect(find.text('Being prepared'), findsOneWidget);
    });

    testWidgets('Completed offers a review only when not yet rated',
        (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Completed'));

      expect(s.calls('GET', 'orders').last.url.queryParameters['tab'],
          'completed',);
      expect(find.text('Order delivered'), findsNWidgets(2));
      expect(find.text('Leave a review'), findsOneWidget);
      expect(find.text('Order again'), findsNWidgets(2));
      expect(find.text('Cancel order'), findsNothing);
    });

    testWidgets('Cancelled rows offer Order again only', (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Cancelled'));

      expect(find.text('Order cancelled'), findsOneWidget);
      expect(find.text('Order again'), findsOneWidget);
      expect(find.text('Track'), findsNothing);
    });

    testWidgets('long names fit a small phone in dark mode', (tester) async {
      final s = _OrdersServer(long: true);
      await _pumpOrders(tester, s, dark: true, small: true);
      expect(tester.takeException(), isNull);
      await _tap(tester, s, find.text('Completed'));
      expect(tester.takeException(), isNull);
      await _tap(tester, s, find.text(_longPlace).first);
      expect(find.byType(OrderDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Order again adds to the cart and names skipped dishes',
        (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Completed'));
      await _tap(tester, s, find.text('Order again').first);

      expect(s.calls('POST', 'orders/c1/reorder'), hasLength(1));
      expect(CatalogService.cartCount.value, 4);
      expect(
        find.text('Added to your cart. Kelewele is no longer on the menu.'),
        findsOneWidget,
      );
      expect(find.text('View cart'), findsOneWidget);
    });
  });

  group('Order details', () {
    testWidgets('shows the lines, the money and the refund of a cancelled '
        'card order', (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Cancelled'));
      await _tap(tester, s, find.text('Buka Place'));

      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Reason: I ordered by mistake'), findsOneWidget);
      expect(find.text('Large · 1 × GH₵ 45'), findsOneWidget);
      expect(find.text('Card, refunded'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('− GH₵ 20'), findsOneWidget);
      expect(find.text('Order again'), findsOneWidget);
      // Placed lines can't change: no − / + here.
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  group('Cancel order', () {
    testWidgets('sends the chosen reason and shows the confirmation',
        (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Cancel order'));

      expect(find.byType(CancelOrderScreen), findsOneWidget);
      final submit = find.widgetWithText(InkWell, 'Cancel order');
      expect(tester.widget<InkWell>(submit).onTap, isNull);

      await _tap(tester, s, find.text('It is taking too long'));
      await _tap(tester, s, submit);

      final body =
          jsonDecode(s.calls('POST', 'orders/a1/cancel').single.body) as Map;
      expect(body, {'reason': 'It is taking too long'});
      expect(find.text('Order cancelled'), findsOneWidget);
      expect(find.textContaining('will be refunded'), findsOneWidget);

      await _tap(tester, s, find.text('Back to my orders'));
      expect(find.byType(OrdersTab), findsOneWidget);
      expect(find.byType(CancelOrderScreen), findsNothing);
    });

    testWidgets('Other needs words before it can be sent', (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Cancel order'));
      await _tap(tester, s, find.text('Other'));

      final submit = find.widgetWithText(InkWell, 'Cancel order');
      expect(tester.widget<InkWell>(submit).onTap, isNull);
      await tester.enterText(find.byType(TextField), 'Wrong address');
      await tester.pump();
      await _tap(tester, s, submit);

      final body =
          jsonDecode(s.calls('POST', 'orders/a1/cancel').single.body) as Map;
      expect(body, {'reason': 'Other', 'note': 'Wrong address'});
    });

    testWidgets('a late cancel shows the server reason and stays',
        (tester) async {
      final s = _OrdersServer(cancelStatus: 409);
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Cancel order'));
      await _tap(tester, s, find.text('I ordered by mistake'));
      await _tap(tester, s, find.widgetWithText(InkWell, 'Cancel order'));

      expect(find.textContaining('can no longer be cancelled'), findsOneWidget);
      expect(find.byType(CancelOrderScreen), findsOneWidget);
    });
  });

  group('Leave a review', () {
    testWidgets('rates each dish once, allows a skip, then the restaurant',
        (tester) async {
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Completed'));
      await _tap(tester, s, find.text('Leave a review'));

      // Jollof in two portions is one page: two dishes in all.
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('Dish 1 of 2'), findsOneWidget);
      final next = find.widgetWithText(InkWell, 'Next');
      expect(tester.widget<InkWell>(next).onTap, isNull);

      await _tap(tester, s, find.byTooltip('4 stars'));
      await tester.enterText(find.byType(TextField), 'Smoky, lovely');
      await _tap(tester, s, next);
      expect(find.text('Dish 2 of 2'), findsOneWidget);
      await _tap(tester, s, find.text('Skip'));

      expect(find.text('How were the restaurant and the delivery?'),
          findsOneWidget,);
      await _tap(tester, s, find.byTooltip('5 stars'));
      await _tap(tester, s, find.text('Submit'));

      final body =
          jsonDecode(s.calls('POST', 'orders/c1/review').single.body) as Map;
      expect(body, {
        'dishes': [
          {'menuItemId': 'm1', 'rating': 4, 'comment': 'Smoky, lovely'},
        ],
        'restaurant': {'rating': 5},
      });
      expect(find.byType(ReviewScreen), findsNothing);
      expect(find.text('Thank you for your review!'), findsOneWidget);
    });
  });

  group('routeAhead', () {
    const route = [
      (lat: 0.0, lng: 0.0),
      (lat: 0.0, lng: 1.0),
      (lat: 0.0, lng: 2.0),
      (lat: 1.0, lng: 2.0),
    ];

    test('starts at the rider spot on the road and keeps the rest', () {
      expect(routeAhead(route, (lat: 0.1, lng: 1.5)), [
        (lat: 0.0, lng: 1.5),
        (lat: 0.0, lng: 2.0),
        (lat: 1.0, lng: 2.0),
      ]);
    });

    test('is the whole road before the rider sets off', () {
      expect(routeAhead(route, null), route);
    });

    test('is only the end once the rider arrives', () {
      expect(routeAhead(route, (lat: 1.0, lng: 2.0)), [(lat: 1.0, lng: 2.0)]);
    });
  });

  group('Live tracking', () {
    testWidgets('shows the rider, dials them and opens their chat',
        (tester) async {
      final opened = <Uri>[];
      launcher = (uri) async {
        opened.add(uri);
        return true;
      };
      final s = _OrdersServer();
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Track').last);

      expect(find.text('Live Tracking'), findsOneWidget);
      expect(find.text('Your rider is on the way'), findsOneWidget);
      expect(find.text('Arriving in about 6 mins'), findsOneWidget);
      expect(find.byIcon(Icons.delivery_dining), findsNWidgets(2));

      // The road ahead of the rider is drawn, and the map cannot rotate.
      final line = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      final points = line.polylines.single.points;
      expect(points.first, isNot(const LatLng(6.68, -1.58)));
      expect(points.last, const LatLng(6.67, -1.57));
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        map.options.interactionOptions.flags & InteractiveFlag.rotate,
        0,
      );

      await _tap(tester, s, find.text('Call your rider'));
      expect(opened.single, Uri.parse('tel:+233200000000'));

      await _tap(tester, s, find.text('Message your rider'));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Kwabena Owusu'), findsOneWidget);
      expect(
        find.text('Send Kwabena Owusu a message about this order.'),
        findsOneWidget,
      );
    });

    testWidgets('turns into Order Delivered, whose stars start the review',
        (tester) async {
      final s = _OrdersServer()
        ..trackingStatuses = ['on_the_way', 'delivered'];
      await _pumpOrders(tester, s);
      await _tap(tester, s, find.text('Track').last);
      expect(find.text('Your rider is on the way'), findsOneWidget);

      await s.server.run(() async {
        await tester.pump(LiveTrackingScreen.every);
        await tester.pumpAndSettle();
      });
      expect(find.byType(OrderDeliveredScreen), findsOneWidget);
      expect(find.textContaining('from Chop Bar has arrived'), findsOneWidget);

      await _tap(tester, s, find.byTooltip('4 stars'));
      expect(find.byType(ReviewScreen), findsOneWidget);
    });

    testWidgets('a single order on Delivery time opens tracking',
        (tester) async {
      _tallPhone(tester);
      final s = _OrdersServer();
      final order = PlacedOrder.fromJson(
        _order('a2', 'on_the_way', restaurant: 'Chop Bar'),
      );
      await s.server.run(() async {
        await tester.pumpApp(DeliveryTimeScreen(orders: [order]));
        await tester.pumpAndSettle();
      });
      await _tap(tester, s, find.text('Track order'));
      expect(find.byType(LiveTrackingScreen), findsOneWidget);
    });
  });
}
