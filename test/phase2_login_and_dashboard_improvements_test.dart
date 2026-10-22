import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/fireguard/fireguard_page.dart';
import 'package:ignivo_app/features/fireguard/guard_home_page.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/settings/edge_connection_page.dart';
import 'package:ignivo_app/widgets/recent_incident_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response _utf8Json(Object? data, [int code = 200]) => http.Response(
      jsonEncode(data),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Đề xuất 1: Đơn giản hóa màn hình đăng nhập (EdgeConnectionPage)', () {
    testWidgets('shows system name, connection state, credentials upfront and hides URLs in advanced tile', (
      tester,
    ) async {
      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((_) async => _utf8Json({'role': 'OWNER'})),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EdgeConnectionPage(api: eye),
        ),
      );
      await tester.pumpAndSettle();

      // System name and connection state indicator
      expect(find.text('Đăng nhập giám sát'), findsOneWidget);
      expect(find.text('Chưa kết nối'), findsOneWidget);

      // Credentials fields are directly visible upfront
      expect(find.byKey(const Key('phone')), findsOneWidget);
      expect(find.byKey(const Key('secret')), findsOneWidget);
      expect(find.byKey(const Key('system-secret')), findsOneWidget);
      expect(find.text('Đăng nhập hệ thống'), findsOneWidget);

      // Advanced server settings expansion tile is present
      expect(find.byKey(const ValueKey('advanced_connection_settings')), findsOneWidget);
      expect(find.text('Thiết lập máy chủ nâng cao'), findsOneWidget);

      // Expanding advanced settings reveals fireeye-url and fireguard-url fields
      await tester.scrollUntilVisible(
        find.text('Thiết lập máy chủ nâng cao'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Thiết lập máy chủ nâng cao'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fireeye-url')), findsOneWidget);
      expect(find.byKey(const Key('fireguard-url')), findsOneWidget);
    });
  });

  group('Đề xuất 4: Dashboard Telemetry & Thứ tự hiển thị trên Mobile (GuardHomePage)', () {
    testWidgets('places recent activity directly below quick cameras and provides expandable hardware telemetry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cam = {
        'id': 1,
        'name': 'Camera Cổng',
        'area': 'Cổng Chính',
        'enabled': true,
        'detect_enabled': true,
        'ai_fps': 15.0,
        'status': {'online': true},
      };

      final inc = {
        'id': 101,
        'trigger_type': 'fire',
        'status': 'notifying',
        'severity': 'critical',
        'area': 'Phòng Khách',
        'camera_name': 'Camera Phòng Khách',
        'created_at': DateTime.now().toIso8601String(),
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _utf8Json({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _utf8Json({'hostname': 'EdgePi'});
          if (r.url.path.endsWith('/status')) {
            return _utf8Json({
              'stringee_configured': true,
              'family_contacts': 1,
              'fire_dept_contacts': 1,
              'vision': {'ready': true, 'total_ai_fps': 15.0},
            });
          }
          if (r.url.path.endsWith('/cameras')) return _utf8Json([cam]);
          if (r.url.path.endsWith('/incidents/active')) return _utf8Json(inc);
          if (r.url.path.endsWith('/incidents')) return _utf8Json([inc]);
          return _utf8Json({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://pi:8080',
          systemName: 'Nhà Riêng',
        ),
      );
      await api.setAuthToken('mock-tok');

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
          home: Scaffold(
            body: GuardHomePage(
              sessionController: session,
              monitoringController: monitoring,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Hero Edge Card appears at the top, followed by Quick Cameras and Recent Activity (matching ignivo-stitch-demo.html)
      final readinessTop = tester.getTopLeft(find.text('Mức sẵn sàng giám sát')).dy;
      final cameraTop = tester.getTopLeft(find.text('Xem nhanh Camera')).dy;
      final recentTop = tester.getTopLeft(find.text('Hoạt động gần đây')).dy;

      expect(readinessTop < cameraTop, isTrue, reason: 'Hero Edge Box card must appear before Camera preview');
      expect(cameraTop < recentTop, isTrue, reason: 'Camera preview must appear before Recent Activity');

      // 2. Verify expandable hardware telemetry section
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('hardware_telemetry_expansion_tile')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Thông số phần cứng & AI Edge'), findsOneWidget);

      await tester.tap(find.text('Thông số phần cứng & AI Edge'));
      await tester.pumpAndSettle();

      expect(find.text('Bộ tăng tốc Hailo AI NPU'), findsOneWidget);
      expect(find.text('Thiết bị biên (Edge Box)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('GuardHomePage recent activity loads and displays incident evidence snapshot', (
      tester,
    ) async {
      final fakeBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final inc = {
        'id': 10,
        'status': 'notifying',
        'severity': 'critical',
        'trigger_type': 'smoke',
        'area': 'Phòng ngủ',
        'created_at': '2026-10-19T10:00:00Z',
        'analysis_image_url': 'http://pi:8080/api/v1/emergency/incidents/10/images/analysis_01.jpg',
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _utf8Json({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _utf8Json({'hostname': 'EdgePi'});
          if (r.url.path.endsWith('/status')) {
            return _utf8Json({
              'vision': {'ready': true, 'total_ai_fps': 15.0},
            });
          }
          if (r.url.path.endsWith('/cameras')) return _utf8Json([]);
          if (r.url.path.endsWith('/incidents/active')) return _utf8Json(null);
          if (r.url.path.endsWith('/incidents')) return _utf8Json([inc]);
          if (r.url.path.contains('/incidents/10/images/analysis_01.jpg')) {
            return http.Response.bytes(fakeBytes, 200, headers: {'content-type': 'image/jpeg'});
          }
          return _utf8Json({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://pi:8080',
          systemName: 'Nhà Riêng',
        ),
      );
      await api.setAuthToken('mock-tok');

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
          home: Scaffold(
            body: GuardHomePage(
              sessionController: session,
              monitoringController: monitoring,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify RecentIncidentTile exists and has loaded Image
      expect(find.byType(RecentIncidentTile), findsOneWidget);
      final tile = tester.widget<RecentIncidentTile>(find.byType(RecentIncidentTile));
      expect(tile.imageBytes, isNotNull);
      expect(tile.triggerType, 'smoke');
      expect(
        find.descendant(
          of: find.byType(RecentIncidentTile),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('displays user-centric "TRẠNG THÁI AI GIÁM SÁT" and "Lịch sử nhận diện & sự cố" on Desktop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _utf8Json({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _utf8Json({'hostname': 'EdgePi'});
          if (r.url.path.endsWith('/status')) {
            return _utf8Json({
              'stringee_configured': true,
              'family_contacts': 1,
              'fire_dept_contacts': 1,
              'vision': {'ready': true, 'total_ai_fps': 15.0},
            });
          }
          if (r.url.path.endsWith('/cameras')) return _utf8Json([]);
          if (r.url.path.endsWith('/incidents/active')) return _utf8Json(null);
          if (r.url.path.endsWith('/incidents')) return _utf8Json([]);
          return _utf8Json({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://pi:8080',
          systemName: 'Biệt Thự',
        ),
      );
      await api.setAuthToken('tok');

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
          home: Scaffold(
            body: GuardHomePage(
              sessionController: session,
              monitoringController: monitoring,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // User-centric KPI title
      expect(find.text('TRẠNG THÁI AI GIÁM SÁT'), findsOneWidget);
      expect(find.text('Đang bảo vệ'), findsOneWidget);

      // Terminology in Quick actions
      expect(find.text('Lịch sử nhận diện & sự cố'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });
  });

  group('Đề xuất 5: Thuật ngữ "Lịch sử nhận diện" (FireguardPage)', () {
    testWidgets('incident tab uses "Lịch sử nhận diện" heading', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _utf8Json({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _utf8Json({'hostname': 'Pi5'});
          if (r.url.path.endsWith('/status')) return _utf8Json({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras')) return _utf8Json([]);
          if (r.url.path.endsWith('/incidents/active')) return _utf8Json(null);
          if (r.url.path.endsWith('/incidents')) return _utf8Json([]);
          return _utf8Json({});
        }),
      );
      await api.setBaseUrl('http://pi:8080');
      await api.setAuthToken('test');
      final realtime = TestRealtime(api);

      await tester.pumpWidget(
        MaterialApp(
          home: FireguardPage(api: api, realtime: realtime),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Incidents tab (tab index 1)
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Lịch sử nhận diện'), findsOneWidget);
      expect(
        find.text('Nhật ký phát hiện và tiến trình xử lý · tối đa 50 sự cố gần nhất'),
        findsOneWidget,
      );
    });
  });

  group('Đề xuất A, B, C: Thẻ trạng thái hệ thống và 4 trụ cột an toàn', () {
    testWidgets('renders 4 safety pillars, live heartbeat, 100% health badge and routes direct taps', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int? navigatedTab;
      var openedDiagnostics = false;

      final cam = {
        'id': 1,
        'name': 'Camera Cổng',
        'area': 'Cổng',
        'enabled': true,
        'detect_enabled': true,
        'status': {'online': true},
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _utf8Json({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _utf8Json({'hostname': 'EdgePi'});
          if (r.url.path.endsWith('/status')) {
            return _utf8Json({
              'stringee_configured': true,
              'family_contacts': 2,
              'fire_dept_contacts': 1,
              'cpu_temp_c': 48,
              'vision': {'ready': true, 'total_ai_fps': 15.0},
            });
          }
          if (r.url.path.endsWith('/cameras')) return _utf8Json([cam]);
          if (r.url.path.endsWith('/incidents/active')) return _utf8Json(null);
          if (r.url.path.endsWith('/incidents')) return _utf8Json([]);
          return _utf8Json({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://pi:8080',
          systemName: 'Biệt Thự Vườn',
        ),
      );
      await api.setAuthToken('mock-tok');

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
          home: Scaffold(
            body: GuardHomePage(
              sessionController: session,
              monitoringController: monitoring,
              onNavigateTab: (tab) => navigatedTab = tab,
              onOpenDiagnostics: () => openedDiagnostics = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Readiness card title & Overall health badge
      expect(find.text('Mức sẵn sàng giám sát'), findsOneWidget);
      expect(find.text('100% Sẵn sàng'), findsOneWidget);
      expect(find.text('Camera giám sát'), findsWidgets);
      expect(find.text('AI Thị giác & Hailo'), findsOneWidget);
      expect(find.text('15.0 FPS · Đang bảo vệ'), findsOneWidget);
      expect(find.text('Thiết bị biên (Pi)'), findsOneWidget);
      expect(find.text('Trực tuyến · 48°C'), findsOneWidget);
      expect(find.text('Gọi người liên hệ'), findsOneWidget);

      // Đề xuất B: Direct 1-tap actions
      // Tap Camera pillar -> navigates to Cameras tab (index 1)
      await tester.tap(find.text('Camera giám sát').first);
      expect(navigatedTab, 1);

      // Tap AI pillar -> opens diagnostics
      await tester.tap(find.text('AI Thị giác & Hailo'));
      expect(openedDiagnostics, isTrue);

      // Tap SOS pillar -> navigates to Settings tab (index 3)
      await tester.tap(find.text('Gọi người liên hệ'));
      expect(navigatedTab, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });
  });
}
