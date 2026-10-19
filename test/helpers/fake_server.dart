import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Answers the app's HTTP calls in tests and remembers what it was sent.
///
/// Every `http.get/post/...` and `MultipartRequest.send` made inside [run]
/// goes to [handler] instead of the network.
class FakeServer {
  FakeServer(this.handler);

  final Future<http.Response> Function(http.Request request) handler;
  final requests = <http.Request>[];

  /// Replies [status] with [body] encoded as JSON (a String is sent as-is).
  static http.Response reply(int status, [Object? body]) => http.Response(
        body is String ? body : jsonEncode(body ?? {}),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Future<T> run<T>(Future<T> Function() body) => http.runWithClient(
        body,
        () => MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      );

  http.Request get last => requests.last;

  Map<String, dynamic> get lastJson =>
      jsonDecode(last.body) as Map<String, dynamic>;
}
