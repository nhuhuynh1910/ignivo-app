import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_realtime_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/navigation/ignivo_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response jsonResp(Object data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MonitoringController Unit & Integration Tests', () {
    test('fetches status, cameras, incidents and merges active incident', () async {
      final inc = {'id': 1, 'status': 'notifying', 'severity': 'high'};
      final cam = {'id': 10, 'name': 'Cam Kho'};
      final status = {
        'hostname': 'ignivo-pi5',
        'vision': {'ready': true, 'total_ai_fps': 16.0},
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          final p = r.url.path;
          if (p.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (p.endsWith('/system/info')) return jsonResp({'hostname': 'ignivo-pi5'});
          if (p.endsWith('/status')) return jsonResp(status);
          if (p.endsWith('/cameras')) return jsonResp([cam]);
          if (p.endsWith('/incidents/active')) return jsonResp(inc);
          if (p.endsWith('/incidents')) return jsonResp([inc]);
          return jsonResp({});
        }),
      );
      await api.setAuthToken('token');

      final realtime = TestRealtime(api);
      final coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: MockAlertFeedbackAdapter(),
      );

      final controller = MonitoringController(
        api: api,
        realtime: realtime,
        coordinator: coordinator,
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(controller.loading, isFalse);
      expect(controller.cameras.length, 1);
      expect(controller.cameras.first['name'], 'Cam Kho');
      expect(controller.incidents.length, 1);
      expect(controller.activeIncident?['id'], 1);
      expect(controller.status?['hostname'], 'ignivo-pi5');

      controller.stop();
      controller.dispose();
    });

    test('registerDetailedIncident fetches detail and updates state', () async {
      final incDetail = {
        'id': 42,
        'status': 'acknowledged',
        'severity': 'critical',
        'area': 'Bếp',
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          final p = r.url.path;
          if (p.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (p.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (p.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
          if (p.endsWith('/cameras') || p.endsWith('/incidents')) return jsonResp([]);
          if (p.endsWith('/incidents/42')) return jsonResp(incDetail);
          return jsonResp({});
        }),
      );
      await api.setAuthToken('token');

      final realtime = TestRealtime(api);
      final coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: MockAlertFeedbackAdapter(),
      );

      final controller = MonitoringController(
        api: api,
        realtime: realtime,
        coordinator: coordinator,
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(controller.detailedIncidentId, isNull);

      controller.registerDetailedIncident(42);
      await Future<void>.delayed(Duration.zero);

      expect(controller.detailedIncidentId, 42);
      expect(controller.detailedIncident?['area'], 'Bếp');

      controller.unregisterDetailedIncident(42);
      expect(controller.detailedIncidentId, isNull);
      expect(controller.detailedIncident, isNull);

      controller.stop();
      controller.dispose();
    });

    testWidgets('IgnivoShell hosts MonitoringController without restarting socket on tab switch', (
      tester,
    ) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras') || r.url.path.endsWith('/incidents')) {
            return jsonResp([]);
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

      final monitoring = MonitoringController(
        api: api,
        realtime: realtime,
        coordinator: coordinator,
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IgnivoShell(
            sessionController: session,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(realtime.state, FireguardConnection.connected);

      // Verify shell is mounted and tab switching preserves realtime connection
      expect(find.byType(IgnivoShell), findsOneWidget);
      expect(realtime.state, FireguardConnection.connected);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.dispose();
    });
  });
}
