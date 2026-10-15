import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';

http.Response json(Object value, [int code = 200]) =>
    http.Response(jsonEncode(value), code);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'concurrent FireEye and FireGuard 401s share one refresh and retry with new Bearer',
    () async {
      var refreshes = 0;
      final pending = Completer<http.Response>();
      final guard = FireguardApiService(
        client: MockClient(
          (r) async => r.headers['Authorization'] == 'Bearer fresh'
              ? json({'role': 'OWNER'})
              : json({'detail': 'Expired'}, 401),
        ),
      );
      final eye = FireeyeApiService(
        fireguard: guard,
        client: MockClient((r) async {
          switch (r.url.path) {
            case '/api/auth/login':
              return json({'token': 'old', 'refresh_token': 'refresh-secret'});
            case '/api/auth/me':
              return json({'role': 'OWNER'});
            case '/api/auth/refresh':
              refreshes++;
              expect(jsonDecode(r.body)['refresh_token'], 'refresh-secret');
              expect(r.headers['Authorization'], isNull);
              return pending.future;
            default:
              return r.headers['Authorization'] == 'Bearer fresh'
                  ? json({'available': true})
                  : json({'detail': 'Expired'}, 401);
          }
        }),
      );
      await eye.login(phoneNumber: '1', secretKey: 'p', systemSecretKey: 's');
      final both = Future.wait([guard.getCurrentUser(), eye.getFaceStatus()]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      pending.complete(json({'token': 'fresh', 'expires_in': 1800}));
      await both;
      expect(refreshes, 1);
      expect(guard.authToken, 'fresh');
      expect(eye.authenticated, isTrue);
    },
  );

  test('late refresh cannot overwrite session after switching Pi', () async {
    final pending = Completer<http.Response>();
    final guard = FireguardApiService();
    final eye = FireeyeApiService(
      fireguard: guard,
      client: MockClient(
        (r) async => switch (r.url.path) {
          '/api/auth/login' => json({'token': 'old', 'refresh_token': 'r'}),
          '/api/auth/refresh' => await pending.future,
          _ => json({'role': 'OWNER'}),
        },
      ),
    );
    await eye.login(phoneNumber: '1', secretKey: 'p', systemSecretKey: 's');
    final result = eye.refreshSession();
    await Future<void>.delayed(Duration.zero);
    await eye.configure('http://another-pi:8000');
    pending.complete(json({'token': 'late'}));
    await expectLater(result, throwsA(isA<FireeyeException>()));
    expect(guard.authToken, isNull);
    expect(await eye.refreshSession(), isFalse);
  });

  for (final status in [401, 503]) {
    test(
      'refresh HTTP $status ${status == 401 ? 'revokes' : 'preserves'} local session',
      () async {
        final guard = FireguardApiService();
        final eye = FireeyeApiService(
          fireguard: guard,
          client: MockClient(
            (r) async => switch (r.url.path) {
              '/api/auth/login' => json({'token': 'old', 'refresh_token': 'r'}),
              '/api/auth/refresh' => json({'detail': 'Unavailable'}, status),
              _ => json({'role': 'OWNER'}),
            },
          ),
        );
        await eye.login(phoneNumber: '1', secretKey: 'p', systemSecretKey: 's');
        await expectLater(
          eye.refreshSession(),
          throwsA(isA<FireeyeException>()),
        );
        expect(guard.authToken, status == 401 ? isNull : 'old');
      },
    );
  }

  test('untrusted evidence URLs cannot receive auth tokens', () async {
    var requests = 0;
    final eye = FireeyeApiService(
      fireguard: FireguardApiService(),
      client: MockClient((r) async {
        requests++;
        return json({});
      }),
    );
    for (final path in [
      'http://elsewhere/photo.jpg',
      '/static/faces/../../private.jpg',
      '/static/faces/a.jpg?token=x',
    ]) {
      await expectLater(eye.getImage(path), throwsA(isA<FireeyeException>()));
    }
    expect(requests, 0);
  });

  test('late logout cannot clear a newly authenticated Pi session', () async {
    final pending = Completer<http.Response>();
    final guard = FireguardApiService();
    final eye = FireeyeApiService(
      fireguard: guard,
      client: MockClient(
        (r) async => r.url.path == '/api/auth/logout'
            ? pending.future
            : json({'role': 'OWNER'}),
      ),
    );
    await eye.useToken('old');
    final result = eye.logout();
    final checked = expectLater(result, throwsA(isA<FireeyeException>()));
    await Future<void>.delayed(Duration.zero);
    await eye.configure('http://new-pi:8000');
    await eye.useToken('new');
    pending.complete(json({'success': true}));
    await checked;
    expect(guard.authToken, 'new');
    expect(eye.authenticated, isTrue);
  });
}
