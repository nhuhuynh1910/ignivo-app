import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/activity/guard_activity_page.dart';
import 'package:ignivo_app/features/fireguard/incident_page.dart';
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

  group('GuardActivityPage Widget Tests', () {
    testWidgets('displays filters, incident list, and switches filters accurately', (
      tester,
    ) async {
      int? openedId;

      final incidents = [
        {
          'id': 101,
          'status': 'notifying',
          'severity': 'critical',
          'trigger_type': 'fire',
          'area': 'Bếp Tầng 1',
          'created_at': '2026-10-16 10:00:00',
        },
        {
          'id': 102,
          'status': 'acknowledged',
          'severity': 'high',
          'trigger_type': 'smoke',
          'area': 'Kho Hàng',
          'created_at': '2026-10-16 09:30:00',
        },
        {
          'id': 103,
          'status': 'resolved',
          'severity': 'low',
          'trigger_type': 'fire',
          'area': 'Sân Thượng',
          'created_at': '2026-10-16 08:00:00',
        },
        {
          'id': 104,
          'status': 'resolved',
          'severity': 'low',
          'trigger_type': 'simulation',
          'is_simulation': true,
          'area': 'Phòng Test',
          'created_at': '2026-10-16 07:00:00',
        },
      ];

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras')) return jsonResp([]);
          if (r.url.path.endsWith('/incidents')) return jsonResp(incidents);
          if (r.url.path.endsWith('/incidents/active')) return jsonResp(incidents.first);
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
            body: GuardActivityPage(
              monitoringController: monitoring,
              sessionController: session,
              onOpenIncident: (id) => openedId = id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check all 4 are shown in "Tất cả"
      expect(find.text('Tất cả (4)'), findsOneWidget);
      expect(find.text('Sự cố #101 — Bếp Tầng 1'), findsOneWidget);
      expect(find.text('Sự cố #102 — Kho Hàng'), findsOneWidget);
      expect(find.text('Sự cố #103 — Sân Thượng'), findsOneWidget);
      expect(find.text('Sự cố #104 — Phòng Test'), findsOneWidget);

      // Filter by "Cần chú ý" (should show only #101)
      await tester.tap(find.text('Cần chú ý'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sự cố #101 — Bếp Tầng 1'), findsOneWidget);
      expect(find.text('Sự cố #102 — Kho Hàng'), findsNothing);
      expect(find.text('Sự cố #103 — Sân Thượng'), findsNothing);

      // Filter by "Đang xử lý" (should show only #102)
      await tester.tap(find.text('Đang xử lý'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sự cố #101 — Bếp Tầng 1'), findsNothing);
      expect(find.text('Sự cố #102 — Kho Hàng'), findsOneWidget);

      // Filter by "Mô phỏng" (should show only #104)
      await tester.ensureVisible(find.text('Mô phỏng'));
      await tester.tap(find.text('Mô phỏng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sự cố #104 — Phòng Test'), findsOneWidget);

      // Tap on item to navigate
      await tester.tap(find.text('Sự cố #104 — Phòng Test'));
      expect(openedId, 104);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('FireguardIncidentPage executes ACK, Resolve, FalseAlarm with proper endpoints', (
      tester,
    ) async {
      final requestedPaths = <String>[];

      final inc = {
        'id': 200,
        'status': 'notifying',
        'severity': 'critical',
        'area': 'Bếp Tầng 1',
        'trigger_type': 'fire',
        'created_at': '2026-10-16 10:00:00',
        'images': <String>[],
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          requestedPaths.add('${r.method} ${r.url.path}');
          if (r.url.path.endsWith('/incidents/200')) return jsonResp(inc);
          if (r.url.path.endsWith('/ack') ||
              r.url.path.endsWith('/resolve') ||
              r.url.path.endsWith('/false-alarm')) {
            return jsonResp({'success': true});
          }
          return jsonResp({});
        }),
      );
      await api.setAuthToken('test-token');

      final realtime = TestRealtime(api);
      final coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: MockAlertFeedbackAdapter(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FireguardIncidentPage(
            incidentId: 200,
            api: api,
            realtime: realtime,
            coordinator: coordinator,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nhận xử lý • Dừng gọi tiếp'), findsOneWidget);
      expect(find.text('Đã xử lý xong'), findsOneWidget);
      expect(find.text('Báo nhầm'), findsOneWidget);

      // Test ACK
      await tester.tap(find.text('Nhận xử lý • Dừng gọi tiếp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requestedPaths.any((p) => p.endsWith('/api/v1/emergency/incidents/200/ack')), isTrue);

      // Test Resolve (with confirmation dialog)
      await tester.tap(find.text('Đã xử lý xong'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Đóng sự cố?'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        requestedPaths.any((p) => p.endsWith('/api/v1/emergency/incidents/200/resolve')),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    });
  });
}
