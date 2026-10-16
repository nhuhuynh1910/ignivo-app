import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/fireguard/guard_home_page.dart';
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

  group('GuardHomePage Widget Tests', () {
    testWidgets('displays calibrated safe banner without claiming absolute safety when empty', (
      tester,
    ) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) {
            return jsonResp({
              'stringee_configured': true,
              'family_contacts': 2,
              'fire_dept_contacts': 1,
              'vision': {'ready': true},
            });
          }
          if (r.url.path.endsWith('/incidents/active')) return jsonResp(null);
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
          systemName: 'Biệt Thự Vườn',
        ),
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
            body: GuardHomePage(
              sessionController: session,
              monitoringController: monitoring,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Biệt Thự Vườn'), findsOneWidget);
      expect(find.text('Chưa ghi nhận cảnh báo trong dữ liệu hiện có'), findsOneWidget);
      expect(find.textContaining('An toàn tuyệt đối'), findsNothing);
      expect(find.text('2 người thân · 1 PCCC'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('displays active incident alert card with action buttons when incident is present', (
      tester,
    ) async {
      int? openedIncidentId;

      final inc = {
        'id': 99,
        'trigger_type': 'fire',
        'status': 'notifying',
        'severity': 'critical',
        'area': 'Bếp Tầng 1',
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras')) return jsonResp([]);
          if (r.url.path.endsWith('/incidents/active')) return jsonResp(inc);
          if (r.url.path.endsWith('/incidents')) return jsonResp([inc]);
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
            body: GuardHomePage(
              sessionController: session,
              monitoringController: monitoring,
              onOpenIncident: (id) => openedIncidentId = id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SỰ CỐ CẦN CHÚ Ý (#99)'), findsOneWidget);
      expect(find.textContaining('Bếp Tầng 1'), findsWidgets);
      expect(find.text('Xem bằng chứng & xử lý'), findsOneWidget);

      await tester.tap(find.text('Xem bằng chứng & xử lý'));
      expect(openedIncidentId, 99);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });
  });
}
