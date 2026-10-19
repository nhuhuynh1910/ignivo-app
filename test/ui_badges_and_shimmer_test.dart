import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/core/theme/brand_tokens.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/navigation/ignivo_shell.dart';
import 'package:ignivo_app/widgets/camera_preview_card.dart';
import 'package:ignivo_app/widgets/ignivo_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response _jsonResp(Object? data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UI Badges & Shimmer Tests', () {
    testWidgets('IgnivoShimmer renders child correctly in test environment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IgnivoShimmer(
              child: Text('Shimmering Content'),
            ),
          ),
        ),
      );

      expect(find.text('Shimmering Content'), findsOneWidget);
    });

    testWidgets('IgnivoShimmerBox renders placeholder container with radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IgnivoShimmerBox(
              width: 120,
              height: 40,
              borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
            ),
          ),
        ),
      );

      expect(find.byType(IgnivoShimmerBox), findsOneWidget);
      expect(find.byType(IgnivoShimmer), findsOneWidget);
    });

    testWidgets('CameraPreviewCard displays IgnivoShimmer and loading text when isSnapshotLoading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraPreviewCard(
              name: 'Camera Nhà Kho',
              area: 'Khu B',
              isOnline: true,
              isSnapshotLoading: true,
              snapshotBytes: null,
            ),
          ),
        ),
      );

      expect(find.byType(CameraPreviewCard), findsOneWidget);
      expect(find.byType(IgnivoShimmer), findsOneWidget);
      expect(find.text('Đang đồng bộ ảnh...'), findsOneWidget);
      expect(find.text('Camera Nhà Kho'), findsOneWidget);
    });

    testWidgets('CameraPreviewCard displays placeholder when snapshotBytes is null and not loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraPreviewCard(
              name: 'Camera Cổng',
              area: 'Cổng Ngoài',
              isOnline: false,
              isSnapshotLoading: false,
              snapshotBytes: null,
            ),
          ),
        ),
      );

      expect(find.text('Camera ngoại tuyến'), findsOneWidget);
      expect(find.byType(IgnivoShimmer), findsNothing);
    });

    testWidgets('IgnivoShell shows dynamic badge on Alert destination when unclosed incidents exist', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return _jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras')) return _jsonResp([]);
          if (r.url.path.endsWith('/incidents/active')) return _jsonResp(null);
          if (r.url.path.endsWith('/incidents')) {
            return _jsonResp([
              {
                'id': 101,
                'status': 'notifying',
                'severity': 'critical',
                'trigger_type': 'flame',
                'created_at': '2026-10-19T10:00:00Z',
              },
            ]);
          }
          return _jsonResp({});
        }),
      );
      await api.setAuthToken('test-token');
      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );
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
      // Ensure API has incident data
      final directIncidents = await api.getIncidents();
      expect(directIncidents.length, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: IgnivoShell(
            sessionController: session,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Badge is rendered on the Alert navigation tab
      expect(find.byType(Badge), findsWidgets);
      expect(find.text('1'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.dispose();
      coordinator.dispose();
    });
  });
}
