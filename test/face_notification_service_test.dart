import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/face_notification_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/settings/guard_settings_page.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response jsonResp(Object? data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FaceNotificationService Unit Tests', () {
    test('Default values and persistence', () async {
      final service = FaceNotificationService.instance;
      await service.initialize();

      expect(service.notifyKnown, isTrue);
      expect(service.notifyUnknown, isTrue);

      await service.setNotifyKnown(false);
      expect(service.notifyKnown, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(FaceNotificationService.keyNotifyKnown), isFalse);

      await service.setNotifyUnknown(false);
      expect(service.notifyUnknown, isFalse);
      expect(prefs.getBool(FaceNotificationService.keyNotifyUnknown), isFalse);

      // Re-enable
      await service.setNotifyKnown(true);
      await service.setNotifyUnknown(true);
      expect(service.notifyKnown, isTrue);
      expect(service.notifyUnknown, isTrue);
    });

    test('Dispatches events according to preferences', () async {
      final service = FaceNotificationService.instance;
      await service.initialize();
      await service.setNotifyKnown(true);
      await service.setNotifyUnknown(true);

      final received = <FaceNotificationEvent>[];
      final sub = service.onFaceEvent.listen((e) => received.add(e));

      // Test Known Person when enabled
      service.dispatchEvent(const FaceNotificationEvent(
        id: 101,
        eventType: 'KNOWN_PERSON',
        message: 'Bác Ba đã có mặt',
        name: 'Bác Ba',
        createdAt: '2026-10-31 10:00:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.length, 1);
      expect(received.first.name, 'Bác Ba');
      expect(received.first.isKnownPerson, isTrue);

      // Disable Known Person
      await service.setNotifyKnown(false);
      service.dispatchEvent(const FaceNotificationEvent(
        id: 102,
        eventType: 'KNOWN_PERSON',
        message: 'Chú Tư đã có mặt',
        name: 'Chú Tư',
        createdAt: '2026-10-31 10:01:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.length, 1); // Not added

      // Test Unknown Person when enabled
      service.dispatchEvent(const FaceNotificationEvent(
        id: 103,
        eventType: 'UNKNOWN_PERSON',
        message: 'Phát hiện người lạ',
        createdAt: '2026-10-31 10:02:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.length, 2);
      expect(received.last.isUnknownPerson, isTrue);

      // Disable Unknown Person
      await service.setNotifyUnknown(false);
      service.dispatchEvent(const FaceNotificationEvent(
        id: 104,
        eventType: 'UNKNOWN_PERSON',
        message: 'Phát hiện người lạ 2',
        createdAt: '2026-10-31 10:03:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.length, 2); // Not added

      await sub.cancel();
    });
  });

  group('Face Notification Settings in GuardSettingsPage', () {
    testWidgets('Can open sheet and toggle notification options', (tester) async {
      final service = FaceNotificationService.instance;
      await service.initialize();
      await service.setNotifyKnown(true);
      await service.setNotifyUnknown(true);

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({
              'token': 'secret-token-123',
              'user': {'role': 'OWNER', 'full_name': 'Trần Gia Chủ', 'phone_number': '0912345678'},
            });
          }
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER', 'full_name': 'Trần Gia Chủ'});
          if (r.url.path.endsWith('/cameras') || r.url.path.endsWith('/incidents')) {
            return jsonResp([]);
          }
          return jsonResp({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://pi:8080',
          systemName: 'Biệt Thự Sen',
        ),
      );
      await session.login(phoneNumber: '0912345678', secretKey: 'key', systemSecretKey: 'sys');

      final realtime = TestRealtime(api);
      final monitoring = MonitoringController(
        api: api,
        realtime: realtime,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GuardSettingsPage(
            sessionController: session,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông báo nhận diện gương mặt'), findsOneWidget);
      expect(find.text('Người quen: Bật · Người lạ: Bật'), findsOneWidget);

      // Open bottom sheet
      await tester.tap(find.text('Thông báo nhận diện gương mặt'));
      await tester.pumpAndSettle();

      expect(find.text('Cài đặt thông báo nhận diện'), findsOneWidget);
      expect(find.text('Thông báo người quen'), findsOneWidget);
      expect(find.text('Cảnh báo người lạ'), findsOneWidget);

      // Toggle off 'Thông báo người quen'
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      expect(service.notifyKnown, isFalse);

      // Close modal
      await tester.ensureVisible(find.text('Xong'));
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      // Verified summary in settings updated
      expect(find.text('Người quen: Tắt · Người lạ: Bật'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.dispose();
    });
  });
}
