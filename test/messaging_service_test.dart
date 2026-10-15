import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/messaging_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MessagingService & Notification Devices', () {
    test('registerDevice sends POST to /notification-devices with token and installationId', () async {
      final calls = <String>[];
      final bodies = <Map<String, dynamic>>[];

      final api = FireguardApiService(
        client: MockClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          if (r.body.isNotEmpty) {
            bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          }
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );
      await api.setAuthToken('test_jwt_token');

      final service = MessagingService(api: api);
      final ok = await service.registerDevice('fcm_token_xyz_123');

      expect(ok, isTrue);
      expect(calls, ['POST /api/v1/emergency/notification-devices']);
      expect(bodies.first['token'], 'fcm_token_xyz_123');
      expect(bodies.first['installation_id'], isNotEmpty);
    });

    test('unregisterDevice sends DELETE to /notification-devices/:id', () async {
      final calls = <String>[];

      final api = FireguardApiService(
        client: MockClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );
      await api.setAuthToken('test_jwt_token');

      final service = MessagingService(api: api);
      final installId = await service.getInstallationId();
      final ok = await service.unregisterDevice();

      expect(ok, isTrue);
      expect(calls, ['DELETE /api/v1/emergency/notification-devices/$installId']);
    });
  });
}
