import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ninja/src/screens/chat_screen.dart';
import 'package:food_ninja/src/screens/help_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/utils/open_link.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _ok(Object data) => {'success': true, 'data': data};

Map<String, dynamic> _msg(
  String id,
  String from,
  String at, {
  String? text,
  List<(String, String)> options = const [],
  Map<String, dynamic>? order,
  String? imageUrl,
}) =>
    {
      '_id': id,
      'chatId': 's1',
      'from': from,
      'createdAt': at,
      if (text != null) 'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (options.isNotEmpty)
        'options': [
          for (final (label, value) in options) {'label': label, 'value': value},
        ],
      if (order != null) 'order': order,
    };

const _menu = [
  ('Order management', '1'),
  ('Payments', '2'),
  ('Account and profile', '3'),
  ('Order tracking', '4'),
  ('Safety', '5'),
];

class _HelpServer {
  _HelpServer({this.long = false}) {
    server = FakeServer(_handle);
  }

  final bool long;
  late final FakeServer server;

  /// Messages the next poll returns.
  List<Map<String, dynamic>> pending = [];

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/v1/', '');
    switch ((r.method, path)) {
      case ('GET', 'chats/support'):
        return FakeServer.reply(
          200,
          _ok({
            'chat': {
              '_id': 's1',
              'kind': 'support',
              'status': 'bot',
              'messages': [
                _msg(
                  'm1',
                  'bot',
                  '2026-11-02T09:00:00Z',
                  text: long
                      ? 'Hi Akosua! ${'I am the YumQuick assistant. ' * 8}'
                      : "Hi Akosua! I'm the YumQuick assistant. Pick a topic.",
                  options: _menu,
                ),
              ],
            },
          }),
        );
      case ('POST', 'chats/s1/messages'):
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        if (body['option'] == '1') {
          return FakeServer.reply(
            201,
            _ok({
              'messages': [
                _msg('m2', 'me', '2026-11-02T09:03:00Z',
                    text: 'Order management',),
                _msg(
                  'm3',
                  'bot',
                  '2026-11-02T09:03:01Z',
                  text: 'You have a current order',
                  order: {
                    '_id': 'o1',
                    'number': 'A1B2C3',
                    'items': 'Jollof and Kelewele',
                    'placedAt': '2026-11-02T08:50:00Z',
                  },
                  options: [
                    ('Order issues', 'order_issues'),
                    ('Order not received', 'order_not_received'),
                    ('Back to menu', 'menu'),
                  ],
                ),
              ],
            }),
          );
        }
        return FakeServer.reply(
          201,
          _ok({
            'messages': [
              _msg('m4', 'me', '2026-11-02T09:05:00Z',
                  text: body['text'] as String,),
            ],
          }),
        );
      case ('POST', 'chats/s1/photo'):
        return FakeServer.reply(
          201,
          _ok({
            'messages': [
              _msg('m6', 'me', '2026-11-02T09:07:00Z',
                  imageUrl: '/uploads/chat/p.jpg',),
              _msg('m7', 'bot', '2026-11-02T09:07:01Z',
                  text: 'Thanks for the photo.',),
            ],
          }),
        );
      case ('GET', 'chats/s1/messages'):
        final out = pending;
        pending = [];
        return FakeServer.reply(200, _ok({'messages': out}));
      case ('GET', 'orders/o9/chat'):
        return FakeServer.reply(409, {
          'message': 'A rider has not picked up this order yet. You can '
              'message them once it is on its way.',
        });
      case ('GET', 'help'):
        String q(String c, int i) => long
            ? 'How do I ${'change something in my $c settings ' * 3}$i?'
            : '$c question $i?';
        return FakeServer.reply(
          200,
          _ok({
            'faqs': [
              for (final c in ['general', 'account', 'services'])
                for (var i = 1; i <= 2; i++)
                  {
                    '_id': 'faq-$c-$i',
                    'category': c,
                    'question': q(c, i),
                    'answer': 'Answer about $c number $i.',
                  },
              {
                '_id': 'faq-x',
                'category': 'services',
                'question': 'Do you deliver to Kumasi?',
                'answer': 'Yes, within 12 km of a restaurant.',
              },
            ],
            'contact': {
              'phone': '+233000000000',
              'email': 'support@example.com',
              'website': 'example.com',
              'whatsapp': '+233000000000',
            },
          }),
        );
    }
    return FakeServer.reply(404, {'message': 'No route $path'});
  }

  List<http.Request> calls(String method, String path) => [
        for (final r in server.requests)
          if (r.method == method && r.url.path == '/api/v1/$path') r,
      ];
}

Future<void> _pump(
  WidgetTester tester,
  _HelpServer s,
  Widget screen, {
  bool dark = false,
}) =>
    s.server.run(() async {
      await tester.pumpApp(screen, dark: dark);
      await tester.pumpAndSettle();
    });

Future<void> _tap(WidgetTester tester, _HelpServer s, Finder finder) =>
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
  });

  group('Help tab', () {
    testWidgets('leads to the support chat and the Help Center',
        (tester) async {
      final s = _HelpServer();
      await _pump(tester, s, const HelpTab());
      expect(find.text('Help'), findsOneWidget);

      await _tap(tester, s, find.text('Help with an order'));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
    });

    testWidgets('Help Center row opens the FAQ', (tester) async {
      final s = _HelpServer();
      await _pump(tester, s, const HelpTab());
      await _tap(tester, s, find.text('Help Center'));
      expect(find.byType(HelpCenterScreen), findsOneWidget);
      expect(find.text('general question 1?'), findsOneWidget);
    });
  });

  group('Support chat', () {
    testWidgets('a bot button sends its option; only the newest buttons work',
        (tester) async {
      final s = _HelpServer();
      await _pump(tester, s, const ChatScreen.support());
      expect(find.textContaining('YumQuick assistant'), findsOneWidget);

      await _tap(tester, s, find.text('Order management'));
      expect(s.server.lastJson, {'option': '1'});
      expect(find.text('Order No. A1B2C3'), findsOneWidget);
      expect(find.text('Jollof and Kelewele'), findsOneWidget);

      // The first menu has moved on: tapping it again sends nothing.
      final before = s.calls('POST', 'chats/s1/messages').length;
      await _tap(tester, s, find.text('Payments'));
      expect(s.calls('POST', 'chats/s1/messages').length, before);
      expect(find.text('Order not received'), findsOneWidget);
    });

    testWidgets('typed text is sent, and new replies arrive by polling',
        (tester) async {
      final s = _HelpServer();
      await _pump(tester, s, const ChatScreen.support());

      await s.server.run(() async {
        await tester.enterText(find.byType(TextField), '  My food is cold  ');
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
      });
      expect(s.server.lastJson, {'text': 'My food is cold'});
      expect(find.text('My food is cold'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      s.pending = [
        _msg('m5', 'staff', '2026-11-02T09:06:00Z',
            text: 'Sorry about that, we are on it.',),
      ];
      await s.server.run(() async {
        await tester.pump(ChatScreen.every);
        await tester.pumpAndSettle();
      });
      final poll = s.calls('GET', 'chats/s1/messages').first;
      expect(
        DateTime.parse(poll.url.queryParameters['after']!),
        DateTime.parse('2026-11-02T09:05:00Z'),
      );
      expect(find.text('Sorry about that, we are on it.'), findsOneWidget);
      expect(find.text('YumQuick team'), findsOneWidget);
    });

    testWidgets('the paperclip sends a photo as an image', (tester) async {
      final dir = Directory.systemTemp.createTempSync('chat_photo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/plate.jpg')..writeAsStringSync('jpeg');
      final pick = ChatScreen.pickPhoto;
      addTearDown(() => ChatScreen.pickPhoto = pick);
      ChatScreen.pickPhoto = () async => file.path;

      final s = _HelpServer();
      await _pump(tester, s, const ChatScreen.support());
      // Reading the file is real I/O, which needs real async.
      await tester.runAsync(
        () => s.server.run(() async {
          await tester.tap(find.byTooltip('Send a photo'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }),
      );
      await tester.pumpAndSettle();

      final upload = s.calls('POST', 'chats/s1/photo').single;
      expect(upload.headers['Authorization'], 'Bearer tok');
      expect(upload.body, contains('content-type: image/jpeg'));
      expect(find.text('Thanks for the photo.'), findsOneWidget);
    });

    testWidgets('long messages fit a small phone in dark mode',
        (tester) async {
      tester.useSmallPhone();
      final s = _HelpServer(long: true);
      await _pump(tester, s, const ChatScreen.support(), dark: true);
      await _tap(tester, s, find.text('Order management'));
      expect(tester.takeException(), isNull);
      expect(find.text('Order No. A1B2C3'), findsOneWidget);
    });
  });

  testWidgets('a rider chat before pickup shows why, with a retry',
      (tester) async {
    final s = _HelpServer();
    await _pump(
      tester,
      s,
      const ChatScreen.rider(orderId: 'o9', riderName: 'Kofi'),
    );
    expect(find.textContaining('has not picked up this order'), findsOneWidget);
    await _tap(tester, s, find.text('Try again'));
    expect(s.calls('GET', 'orders/o9/chat'), hasLength(2));
  });

  group('Help Center', () {
    testWidgets('FAQs by category, search across all, answers open',
        (tester) async {
      final s = _HelpServer();
      await _pump(tester, s, const HelpCenterScreen());
      expect(find.text('general question 1?'), findsOneWidget);
      expect(find.text('account question 1?'), findsNothing);

      await _tap(tester, s, find.text('Account'));
      expect(find.text('account question 2?'), findsOneWidget);

      await s.server.run(() async {
        await tester.enterText(find.byType(TextField), 'kumasi');
        await tester.pumpAndSettle();
      });
      expect(find.text('Do you deliver to Kumasi?'), findsOneWidget);
      expect(find.text('account question 2?'), findsNothing);

      await _tap(tester, s, find.text('Do you deliver to Kumasi?'));
      expect(find.text('Yes, within 12 km of a restaurant.'), findsOneWidget);

      await s.server.run(() async {
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
      });
      expect(find.textContaining('No answers match'), findsOneWidget);
    });

    testWidgets('Contact us opens the dialer and links', (tester) async {
      final opened = <Uri>[];
      launcher = (uri) async {
        opened.add(uri);
        return true;
      };
      final s = _HelpServer();
      await _pump(tester, s, const HelpCenterScreen());
      await _tap(tester, s, find.text('Contact us'));
      expect(find.text('Facebook'), findsNothing);

      await _tap(tester, s, find.text('Customer service'));
      await _tap(tester, s, find.text('support@example.com'));
      await _tap(tester, s, find.text('+233000000000').first);
      await _tap(tester, s, find.text('WhatsApp'));
      await _tap(tester, s, find.text('+233000000000').last);
      expect(opened, [
        Uri.parse('mailto:support@example.com'),
        Uri.parse('tel:+233000000000'),
        Uri.parse('https://wa.me/233000000000'),
      ]);
    });

    testWidgets('a link the phone cannot open says so', (tester) async {
      launcher = (uri) async => false;
      final s = _HelpServer();
      await _pump(tester, s, const HelpCenterScreen());
      await _tap(tester, s, find.text('Contact us'));
      await _tap(tester, s, find.text('Website'));
      await _tap(tester, s, find.text('example.com'));
      expect(find.text("Couldn't open that link."), findsOneWidget);
    });

    testWidgets('long questions fit a small phone in dark mode',
        (tester) async {
      tester.useSmallPhone();
      final s = _HelpServer(long: true);
      await _pump(tester, s, const HelpCenterScreen(), dark: true);
      await _tap(tester, s, find.text('Services'));
      expect(tester.takeException(), isNull);
    });
  });
}
