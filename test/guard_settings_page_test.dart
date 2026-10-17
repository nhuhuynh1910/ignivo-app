import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/settings/diagnostics_page.dart';
import 'package:ignivo_app/features/settings/guard_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response jsonResp(Object? data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GuardSettingsPage & Diagnostics Widget Tests', () {
    testWidgets('renders account info, settings options, and logout flow', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({
              'token': 'secret-token-1234567890',
              'user': {'role': 'OWNER', 'full_name': 'Trần Gia Chủ', 'phone_number': '0912345678'},
            });
          }
          if (r.url.path.endsWith('/auth/me')) {
            return jsonResp({
              'role': 'OWNER',
              'full_name': 'Trần Gia Chủ',
              'phone_number': '0912345678',
            });
          }
          if (r.url.path.endsWith('/auth/logout')) return jsonResp({'success': true});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi-home'});
          if (r.url.path.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
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
      final coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: MockAlertFeedbackAdapter(),
      );

      final monitoring = MonitoringController(
        api: api,
        realtime: realtime,
        coordinator: coordinator,
      );

      monitoring.start();
      await monitoring.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: GuardSettingsPage(
            sessionController: session,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trần Gia Chủ'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('VAI TRÒ: OWNER (TOÀN QUYỀN)'), findsOneWidget);
      expect(find.text('Người liên hệ khẩn cấp'), findsOneWidget);
      expect(find.text('Địa chỉ khẩn cấp'), findsOneWidget);
      expect(find.text('Cảnh báo hoạt động khi mở ứng dụng'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Đăng xuất tài khoản'), 100);
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất tài khoản'), findsOneWidget);

      // Tap logout and confirm
      await tester.tap(find.text('Đăng xuất tài khoản'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Đăng xuất tài khoản?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(session.isAuthenticated, isFalse);
      expect(api.authToken, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('DiagnosticsPage masks secret token and shows hardware details', (tester) async {
      final status = {
        'hostname': 'ignivo-pi-5',
        'device_id': 'edge-box-999',
        'stringee_configured': true,
        'family_contacts': 3,
        'fire_dept_contacts': 1,
        'vision': {
          'ready': true,
          'total_ai_fps': 18.5,
        },
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp(status);
          if (r.url.path.endsWith('/status')) return jsonResp(status);
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
          deviceId: 'edge-box-999',
        ),
      );
      await api.setAuthToken('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.super_secret_payload_token_xyz123');

      final realtime = TestRealtime(api);
      final coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: MockAlertFeedbackAdapter(),
      );

      final monitoring = MonitoringController(
        api: api,
        realtime: realtime,
        coordinator: coordinator,
      );

      monitoring.start();
      await monitoring.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: DiagnosticsPage(
            monitoringController: monitoring,
            sessionController: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Chẩn đoán hệ thống'), findsOneWidget);
      expect(find.text('ignivo-pi-5'), findsOneWidget);
      expect(find.text('edge-box-999'), findsOneWidget);
      expect(find.text('Sẵn sàng'), findsWidgets);
      expect(find.text('18.5 FPS'), findsOneWidget);
      expect(find.text('3 người'), findsOneWidget);
      expect(find.text('1 cơ quan'), findsOneWidget);

      await tester.scrollUntilVisible(find.textContaining('Mã phiên (RAM masked)'), 100);

      // Verify token is masked and raw token is NEVER printed
      expect(find.textContaining('eyJhbG••••••••z123'), findsOneWidget);
      expect(
        find.textContaining('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.super_secret_payload_token_xyz123'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });
  });
}
