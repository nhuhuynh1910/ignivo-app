import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_realtime_service.dart';

Future<void> until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('State not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late FireguardApiService api;
  late FireguardRealtimeService realtime;
  final peers = <WebSocket>[];
  final tokens = <String?>[];
  var reject = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    peers.clear();
    tokens.clear();
    reject = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.uri.path, '/api/v1/emergency/ws');
      tokens.add(request.uri.queryParameters['token']);
      if (reject) {
        request.response.statusCode = 403;
        await request.response.close();
      } else {
        final peer = await WebSocketTransformer.upgrade(request);
        peers.add(peer);
        peer.listen((_) {}, onError: (Object _) {});
      }
    });
    api = FireguardApiService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'role': 'OWNER'}), reject ? 401 : 200),
      ),
    );
    await api.setBaseUrl('http://127.0.0.1:${server.port}');
    await api.setAuthToken('test-token');
    realtime = FireguardRealtimeService(
      api,
      retryDelay: const Duration(milliseconds: 30),
    );
  });
  tearDown(() async {
    realtime.dispose();
    for (final peer in peers) {
      await peer.close();
    }
    await server.close(force: true);
  });

  test(
    'authenticated WS parses incidents and calls, ignores malformed frames',
    () async {
      final events = <FireguardEvent>[];
      final subscription = realtime.events.listen(events.add);
      realtime.start();
      await until(() => realtime.state == FireguardConnection.connected);
      expect(tokens, ['test-token']);
      peers.single.add('invalid json');
      peers.single.add(
        jsonEncode({
          'event': 'incident.created',
          'data': {'id': 'invalid'},
        }),
      );
      peers.single.add(
        jsonEncode({
          'event': 'incident.created',
          'data': {'id': 42},
        }),
      );
      peers.single.add(
        jsonEncode({
          'event': 'call.updated',
          'data': {'incident_id': 42, 'status': 'answered'},
        }),
      );
      await until(() => events.length == 2);
      expect(events.map((e) => e.incidentId), [42, 42]);
      expect(events.last.data['status'], 'answered');
      await subscription.cancel();
    },
  );

  test('transport loss reconnects; stop prevents further reconnects', () async {
    realtime.start();
    await until(() => realtime.state == FireguardConnection.connected);
    await peers.first.close(1001);
    await until(
      () =>
          peers.length == 2 && realtime.state == FireguardConnection.connected,
    );
    realtime.stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tokens.length, 2);
    expect(realtime.state, FireguardConnection.stopped);
  });

  test('4401 closes shared session and stops retrying', () async {
    realtime.start();
    await until(() => realtime.state == FireguardConnection.connected);
    await peers.single.close(4401);
    await until(() => realtime.state == FireguardConnection.expired);
    expect(api.authToken, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tokens.length, 1);
  });

  test('pre-accept auth rejection checks HTTP auth and stops on 401', () async {
    reject = true;
    realtime.start();
    await until(() => realtime.state == FireguardConnection.expired);
    expect(api.authToken, isNull);
    expect(tokens.length, 1);
  });

  test('token replacement opens new socket; logout closes it', () async {
    realtime.start();
    await until(() => realtime.state == FireguardConnection.connected);
    await api.setAuthToken('replacement');
    await until(
      () =>
          peers.length == 2 && realtime.state == FireguardConnection.connected,
    );
    expect(tokens, ['test-token', 'replacement']);
    await api.setAuthToken(null);
    expect(realtime.state, FireguardConnection.expired);
  });

  test('secure origin uses wss and query encodes token', () async {
    await api.setBaseUrl('https://pi.example');
    await api.setAuthToken('a+b/c=');
    expect(api.websocketUri.scheme, 'wss');
    expect(api.websocketUri.queryParameters['token'], 'a+b/c=');
  });
}
