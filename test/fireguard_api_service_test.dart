import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'login uses FireEye contract then verifies token with auth/me',
    () async {
      final requests = <http.Request>[];
      final api = FireguardApiService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/auth/login')) {
            expect(jsonDecode(request.body), {
              'phone_number': '0912345678',
              'secret_key': 'secret',
              'system_secret_key': 'system',
              'device_name': 'IGNIVO Mobile App',
            });
            return json({
              'token': 'fireeye-token',
              'user': {'role': 'OWNER'},
            });
          }
          expect(request.url.path, '/api/v1/emergency/auth/me');
          expect(request.headers['Authorization'], 'Bearer fireeye-token');
          return json({'role': 'OWNER'});
        }),
      );
      expect(
        await api.login(
          phoneNumber: '0912345678',
          secretKey: 'secret',
          systemSecretKey: 'system',
        ),
        isTrue,
      );
      expect(api.canConfigure, isTrue);
      expect(requests.length, 2);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'fireguard_edge_auth_token',
        ),
        isNull,
      );
    },
  );

  test('concurrent init does not overwrite freshly configured URL', () async {
    SharedPreferences.setMockInitialValues({
      'fireguard_edge_base_url': 'http://old.local:8080',
    });
    final api = FireguardApiService();
    await Future.wait([api.init(), api.setBaseUrl('http://new.local:8080/')]);
    expect(api.baseUrl, 'http://new.local:8080');
  });

  test(
    'changing host clears credentials and prevents credential forwarding',
    () async {
      final api = FireguardApiService();
      await api.setAuthToken('Bearer abc');
      expect(
        api.headersForUrl('${api.apiPrefix}/cameras/7/stream')['Authorization'],
        'Bearer abc',
      );
      expect(api.headersForUrl('https://unrelated.test/video'), isEmpty);
      expect(api.headersForUrl('/relative'), isEmpty);
      await api.setBaseUrl('https://pi.example');
      expect(api.authToken, isNull);
      expect(
        api.headersForUrl('${api.apiPrefix}/cameras/7/stream')['Authorization'],
        isNull,
      );
    },
  );

  test(
    'base URL rejects paths, userinfo, query, missing host and non HTTP',
    () {
      for (final url in [
        '',
        'ftp://pi',
        'http://pi/api',
        'http://user:pass@pi',
        'http://pi?token=a',
        'http://pi#x',
      ]) {
        expect(
          () => FireguardApiService.normalizeBaseUrl(url),
          throwsFormatException,
        );
      }
      expect(
        FireguardApiService.normalizeBaseUrl('192.168.1.50:8080/'),
        'http://192.168.1.50:8080',
      );
    },
  );

  test(
    'health requires FireGuard identity and is not authentication',
    () async {
      final api = FireguardApiService(
        client: MockClient(
          (_) async => json({'status': 'ok', 'service': 'fireguard'}),
        ),
      );
      expect(await api.checkConnection(), isTrue);
      expect(api.currentUser, isNull);
      final other = FireguardApiService(
        client: MockClient(
          (_) async => json({'status': 'ok', 'service': 'other'}),
        ),
      );
      expect(await other.checkConnection(), isFalse);
    },
  );

  test(
    '401 is surfaced instead of empty cameras and clears expired token',
    () async {
      final api = FireguardApiService(
        client: MockClient((_) async => json({'detail': 'expired'}, 401)),
      );
      await api.setAuthToken('expired');
      await expectLater(
        api.getCameras(),
        throwsA(
          isA<FireguardException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(api.authToken, isNull);
      expect(api.lastError, contains('đăng nhập lại'));
    },
  );

  test(
    'incident images use exact numeric ID and Bearer header without query token',
    () async {
      final api = FireguardApiService(
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/emergency/incidents/42/images/analysis_2.jpg',
          );
          expect(request.url.query, isEmpty);
          expect(request.headers['Authorization'], 'Bearer abc');
          return http.Response.bytes([255, 216, 255, 217], 200);
        }),
      );
      await api.setAuthToken('abc');
      expect(await api.getIncidentImage(42, 'analysis_2.jpg'), [
        255,
        216,
        255,
        217,
      ]);
      await expectLater(
        api.getIncidentImage(42, '../bad.jpg'),
        throwsA(isA<FireguardException>()),
      );
    },
  );

  test(
    'closed incident returns failure with server detail, never success',
    () async {
      final api = FireguardApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/emergency/incidents/42/ack');
          expect(request.method, 'POST');
          return json({'detail': 'Sự cố đã đóng'}, 409);
        }),
      );
      expect(await api.acknowledgeIncident(42), isFalse);
      expect(api.lastError, 'Sự cố đã đóng');
    },
  );

  test(
    'test call checks ok in HTTP 200 response and distinguishes mock',
    () async {
      var ok = false;
      final api = FireguardApiService(
        client: MockClient(
          (_) async => json({'ok': ok, 'provider': 'mock', 'error': 'failed'}),
        ),
      );
      expect(await api.testCall(1), isFalse);
      expect(api.lastError, 'failed');
      ok = true;
      expect(await api.testCall(1), isTrue);
      expect(api.lastCallProvider, 'mock');
    },
  );

  test(
    'FastAPI validation details and forbidden writes remain visible',
    () async {
      final api = FireguardApiService(
        client: MockClient(
          (_) async => json({
            'detail': [
              {
                'loc': ['body', 'phone'],
                'msg': 'Số điện thoại không hợp lệ',
              },
            ],
          }, 422),
        ),
      );
      expect(await api.createContact(name: 'Mẹ', phone: 'abc'), isNull);
      expect(api.lastError, 'Số điện thoại không hợp lệ');
      final forbidden = FireguardApiService(
        client: MockClient(
          (_) async => json({'detail': 'Chỉ OWNER hoặc ADMIN'}, 403),
        ),
      );
      expect(await forbidden.deleteContact(1), isFalse);
      expect(forbidden.lastError, 'Chỉ OWNER hoặc ADMIN');
    },
  );

  test(
    'system status maps vision.ready and never treats partial 401 as success',
    () async {
      var statusCode = 200;
      final api = FireguardApiService(
        client: MockClient(
          (request) async => request.url.path.endsWith('/info')
              ? json({'hostname': 'pi', 'cpu_temp_c': 42})
              : json({
                  'vision': {'ready': true, 'total_ai_fps': 12},
                }, statusCode),
        ),
      );
      expect((await api.getSystemStatus())?['hailo_ready'], isTrue);
      statusCode = 401;
      expect(await api.getSystemStatus(), isNull);
    },
  );

  test('location replacement includes coordinates and all fields', () async {
    final api = FireguardApiService(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/emergency/settings/location');
        final body = jsonDecode(request.body) as Map;
        expect(
          body.keys,
          containsAll([
            'address',
            'building',
            'floor',
            'room',
            'landmark',
            'latitude',
            'longitude',
            'notes',
          ]),
        );
        expect(body['latitude'], 10.8);
        expect(body['longitude'], 106.7);
        return json(body);
      }),
    );
    expect(
      await api.updateLocationSettings(
        address: 'Địa chỉ',
        latitude: 10.8,
        longitude: 106.7,
      ),
      isTrue,
    );
  });

  test('network failure is distinct from an empty incident list', () async {
    final api = FireguardApiService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(api.getIncidents(), throwsA(isA<FireguardException>()));
  });
}
