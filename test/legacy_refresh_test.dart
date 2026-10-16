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
  for (final valid in [true, false]) {
    test('cookie refresh verifies returned session (valid=$valid)', () async {
      final guard = FireguardApiService();
      var refreshes = 0;
      final eye = FireeyeApiService(
        fireguard: guard,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({'token': 'old', 'refresh_token': 'refresh-secret'}),
              200,
            );
          }
          if (r.url.path.endsWith('/refresh')) {
            refreshes++;
            expect(r.headers['cookie'], 'refresh_token=refresh-secret');
            expect(r.followRedirects, isFalse);
            return http.Response(
              '{"success":true}',
              200,
              headers: {
                'set-cookie':
                    'access_token=fresh; HttpOnly; Path=/; SameSite=lax, refresh_token=rotated; Path=/',
              },
            );
          }
          expect(
            r.headers['cookie'],
            isNull,
            reason: 'Refresh cookie must stay on auth refresh endpoint',
          );
          if (!valid && r.headers['authorization'] == 'Bearer fresh') {
            return http.Response('{"detail":"Session has expired"}', 401);
          }
          return http.Response('{"role":"OWNER"}', 200);
        }),
      );
      await eye.login(phoneNumber: '1', secretKey: 'p', systemSecretKey: 's');
      if (valid) {
        expect(await eye.refreshSession(), isTrue);
        expect(guard.authToken, 'fresh');
      } else {
        await expectLater(
          eye.refreshSession(),
          throwsA(isA<FireeyeException>()),
        );
        expect(guard.authToken, isNull);
      }
      expect(refreshes, 1);
    });
  }
  test(
    'missing integration endpoint is unsupported without legacy fallback',
    () async {
      final paths = <String>[];
      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response('{"detail":"Not Found"}', 404);
        }),
      );
      final capability = await eye.getCameraCapabilities();
      expect(capability['status'], 'unsupported');
      expect(capability['ptz'], isFalse);
      expect(paths, ['/api/integration/camera']);
    },
  );
}
