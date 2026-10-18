import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/camera/camera_live_page.dart';
import 'package:ignivo_app/features/camera/guard_cameras_page.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response jsonResp(Object? data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GuardCamerasPage Widget Tests', () {
    testWidgets('displays empty state when no cameras configured', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras') || r.url.path.endsWith('/incidents')) {
            return jsonResp([]);
          }
          if (r.url.path.endsWith('/incidents/active')) return jsonResp(null);
          return jsonResp({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );
      await api.setAuthToken('test-token');

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
            body: GuardCamerasPage(
              monitoringController: monitoring,
              sessionController: session,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Chưa phát hiện camera kết nối'), findsOneWidget);
      expect(find.text('Chưa có camera nào được cấu hình'), findsOneWidget);
      expect(find.text('Xem hướng dẫn thiết lập'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('renders camera card list with live view button and config button for OWNER', (
      tester,
    ) async {
      int? openedCamId;

      final cams = [
        {
          'id': 1,
          'name': 'Camera Cổng Chính',
          'area': 'Cổng',
          'enabled': true,
          'detect_enabled': true,
          'ai_fps': 10,
          'status': {'online': true},
        },
        {
          'id': 2,
          'name': 'Camera Nhà Bếp',
          'area': 'Bếp Tầng 1',
          'enabled': true,
          'detect_enabled': false,
          'ai_fps': 5,
          'status': {'online': false},
        },
      ];

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'token': 'test-token', 'user': {'role': 'OWNER'}});
          }
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras')) return jsonResp(cams);
          if (r.url.path.endsWith('/incidents')) return jsonResp([]);
          if (r.url.path.endsWith('/incidents/active')) return jsonResp(null);
          return jsonResp({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );
      await session.login(phoneNumber: '0901234567', secretKey: 'secret', systemSecretKey: 'sys');

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

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      monitoring.start();
      await monitoring.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardCamerasPage(
              monitoringController: monitoring,
              sessionController: session,
              onOpenLiveView: (id) => openedCamId = id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1/2 camera trực tuyến'), findsOneWidget);
      expect(find.text('Camera Cổng Chính'), findsOneWidget);
      expect(find.text('Camera Nhà Bếp'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('AI nhận diện: BẬT'), findsOneWidget);
      expect(find.text('AI: TẮT'), findsOneWidget);

      // OWNER should see edit button
      expect(find.text('Sửa'), findsNWidgets(2));

      // Tap on Live View
      await tester.ensureVisible(find.text('Xem trực tiếp (Live View)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem trực tiếp (Live View)').first);
      expect(openedCamId, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('CameraLivePage displays stream container and toggles fullscreen', (tester) async {
      final cam = {
        'id': 1,
        'name': 'Camera Cổng Chính',
        'area': 'Cổng',
        'enabled': true,
        'detect_enabled': true,
        'ai_fps': 10,
        'status': {'online': true},
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/cameras')) return jsonResp([cam]);
          return jsonResp({});
        }),
      );
      await api.setAuthToken('test-token');

      await tester.pumpWidget(
        MaterialApp(
          home: CameraLivePage(
            cameraId: 1,
            api: api,
            initialCamera: cam,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Camera Cổng Chính'), findsOneWidget);
      expect(find.text('Cổng'), findsWidgets);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      // Toggle fullscreen
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.close), findsOneWidget);

      // Exit fullscreen
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
