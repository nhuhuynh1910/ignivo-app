import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  http.Response json(Object data, [int code = 200]) =>
      http.Response(jsonEncode(data), code);

  test(
    'FireEye login/me/logout; verified Bearer token is shared with FireGuard',
    () async {
      final calls = <String>[];
      final guard = FireguardApiService(
        client: MockClient((request) async {
          expect(request.url.port, 8080);
          expect(request.headers['Authorization'], 'Bearer shared-token');
          return json({'role': 'OWNER'});
        }),
      );
      await guard.setBaseUrl('http://100.95.189.60:8080');
      final eye = FireeyeApiService(
        fireguard: guard,
        client: MockClient((request) async {
          calls.add(request.url.path);
          expect(request.url.port, 8000);
          if (request.url.path.endsWith('/login')) {
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], isNull);
            expect(jsonDecode(request.body), {
              'phone_number': '0912345678',
              'secret_key': 'secret',
              'system_secret_key': 'system',
              'device_name': 'IGNIVO Mobile App',
            });
            return json({'token': 'shared-token'});
          }
          expect([
            '/api/auth/me',
            '/api/auth/logout',
          ], contains(request.url.path));
          expect(request.headers['Authorization'], 'Bearer shared-token');
          return json({'role': 'OWNER'});
        }),
      );
      await eye.login(
        phoneNumber: '0912345678',
        secretKey: 'secret',
        systemSecretKey: 'system',
      );
      await guard.getCurrentUser();
      expect(eye.authenticated, isTrue);
      await eye.logout();
      expect(calls, ['/api/auth/login', '/api/auth/me', '/api/auth/logout']);
      expect(guard.authToken, isNull);
      expect(guard.currentUser, isNull);
    },
  );

  test(
    '401 clears shared auth; changing either origin invalidates token',
    () async {
      var code = 200;
      final guard = FireguardApiService();
      final eye = FireeyeApiService(
        fireguard: guard,
        client: MockClient((_) async => json({'role': 'OWNER'}, code)),
      );
      await eye.useToken('token');
      code = 401;
      await expectLater(eye.getCurrentUser(), throwsA(isA<FireeyeException>()));
      expect(guard.authToken, isNull);
      expect(eye.authenticated, isFalse);
      code = 200;
      await eye.useToken('new-token');
      await eye.configure('http://other:8000');
      expect(guard.authToken, isNull);
      await eye.useToken('other-token');
      await guard.setBaseUrl('http://third:8080');
      expect(guard.authToken, isNull);
      expect(eye.authenticated, isFalse);
    },
  );

  test('old responses cannot authenticate a different URL pair', () async {
    final pending = Completer<http.Response>();
    final eye = FireeyeApiService(
      fireguard: FireguardApiService(),
      client: MockClient((_) => pending.future),
    );
    await eye.init();
    final result = eye.getCurrentUser();
    await Future<void>.delayed(Duration.zero);
    await eye.configure('http://new:8000');
    pending.complete(json({'role': 'OWNER'}));
    await expectLater(result, throwsA(isA<FireeyeException>()));
    expect(eye.authenticated, isFalse);
  });

  test('unverified login token is cleared', () async {
    final guard = FireguardApiService();
    final eye = FireeyeApiService(
      fireguard: guard,
      client: MockClient(
        (r) async => r.url.path.endsWith('/login')
            ? json({'token': 'bad'})
            : json({'detail': 'Invalid'}, 401),
      ),
    );
    await expectLater(
      eye.login(phoneNumber: '1', secretKey: 'x', systemSecretKey: 'y'),
      throwsA(isA<FireeyeException>()),
    );
    expect(guard.authToken, isNull);
  });

  test('saved auth URL is bound to the same Pi', () async {
    SharedPreferences.setMockInitialValues({
      'fireeye_guard_origin': 'http://old:8080',
      'fireeye_base_url': 'http://old:8000',
    });
    final guard = FireguardApiService();
    await guard.setBaseUrl('http://new:8080');
    final eye = FireeyeApiService(fireguard: guard);
    await eye.init();
    expect(eye.baseUrl, 'http://new:8000');
  });
}
