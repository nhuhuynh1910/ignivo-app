import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/core/theme/app_theme.dart';
import 'package:ignivo_app/core/theme/brand_tokens.dart';
import 'package:ignivo_app/features/fireguard/camera_editor_page.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/settings/diagnostics_page.dart';
import 'package:ignivo_app/features/settings/emergency_contacts_page.dart';
import 'package:ignivo_app/features/settings/emergency_location_page.dart';
import 'package:ignivo_app/features/settings/guard_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response _jsonResp(Object? data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Gói B5: Brand UI/UX Auxiliary Pages & Settings Tests', () {
    testWidgets('GuardSettingsPage uses brand tokens for cards, avatars and buttons in dark mode', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return _jsonResp({
              'token': 'secret-1234567890',
              'user': {'role': 'OWNER', 'full_name': 'Nguyễn Quản Trị', 'phone_number': '0988888888'},
            });
          }
          if (r.url.path.endsWith('/auth/me')) {
            return _jsonResp({
              'role': 'OWNER',
              'full_name': 'Nguyễn Quản Trị',
              'phone_number': '0988888888',
            });
          }
          return _jsonResp({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://pi:8080',
          systemName: 'Trụ Sở Chính',
        ),
      );
      await session.login(phoneNumber: '0988888888', secretKey: 'k', systemSecretKey: 's');

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

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GuardSettingsPage(
            sessionController: session,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nguyễn Quản Trị'), findsOneWidget);
      expect(find.text('0988888888'), findsOneWidget);
      expect(find.text('Người liên hệ khẩn cấp'), findsOneWidget);
      expect(find.text('Địa chỉ khẩn cấp'), findsOneWidget);
      expect(find.text('Chẩn đoán hệ thống Edge Pi'), findsOneWidget);

      // Verify logout button exists with critical color
      await tester.scrollUntilVisible(find.text('Đăng xuất tài khoản'), 100);
      final logoutBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Đăng xuất tài khoản'),
      );
      expect(logoutBtn.style?.foregroundColor?.resolve({}), BrandTokens.darkCriticalFg);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('EmergencyContactsPage renders properly in dark mode without hardcoded white cards', (tester) async {
      final contacts = [
        {'id': 1, 'name': 'Bố', 'phone': '0901111111', 'kind': 'family', 'relation': 'Bố', 'enabled': true},
        {'id': 2, 'name': 'PCCC Quận 1', 'phone': '114', 'kind': 'fire_dept', 'relation': 'Cứu hoả', 'enabled': true},
      ];

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/contacts')) {
            return _jsonResp(contacts);
          }
          return _jsonResp({});
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: EmergencyContactsPage(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bố'), findsOneWidget);
      expect(find.text('Người thân'), findsOneWidget);
      expect(find.text('PCCC Quận 1'), findsOneWidget);
      expect(find.text('PCCC/Bảo vệ'), findsOneWidget);

      // Verify card containers use cardColor (dark surface), not Colors.white
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, BrandTokens.darkBackground);
    });

    testWidgets('EmergencyLocationPage info banner and form use themed surfaces in dark mode', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/settings/location')) {
            return _jsonResp({
              'address': 'Toà nhà Ignivo, 123 Cầu Giấy',
              'building': 'Block A',
              'floor': '8',
              'room': 'Phòng 801',
              'landmark': 'Cạnh ga metro',
              'notes': 'Cửa có chuông thông minh',
            });
          }
          return _jsonResp({});
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: EmergencyLocationPage(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vị trí & Địa chỉ khẩn cấp'), findsOneWidget);
      expect(find.textContaining('giọng đọc AI của FireGuard'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, BrandTokens.darkBackground);
    });

    testWidgets('GuardCameraEditor displays themed info banners for create and edit modes', (tester) async {
      final api = FireguardApiService(client: MockClient((r) async => _jsonResp({})));

      // 1. Create mode (camera == null)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GuardCameraEditor(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm camera'), findsOneWidget);
      expect(find.textContaining('Việc thêm camera mới (RTSP/USB)'), findsOneWidget);

      // 2. Edit mode (camera != null)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GuardCameraEditor(
            api: api,
            camera: const {
              'id': 1,
              'name': 'Camera Cửa Chính',
              'area': 'Cổng',
              'ai_fps': 10,
              'enabled': true,
              'detect_enabled': true,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sửa camera'), findsOneWidget);
      expect(find.textContaining('Nguồn video và thông tin RTSP được bảo mật'), findsOneWidget);
    });

    testWidgets('DiagnosticsPage displays system metrics with proper semantic tokens', (tester) async {
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
          if (r.url.path.endsWith('/auth/me')) return _jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _jsonResp(status);
          if (r.url.path.endsWith('/status')) return _jsonResp(status);
          if (r.url.path.endsWith('/cameras') || r.url.path.endsWith('/incidents')) {
            return _jsonResp([]);
          }
          return _jsonResp({});
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
          theme: AppTheme.darkTheme,
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

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });
  });
}
