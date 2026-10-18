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
import 'package:ignivo_app/features/fireguard/guard_home_page.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/settings/guard_settings_page.dart';
import 'package:ignivo_app/widgets/ignivo_brand_logo.dart';
import 'package:ignivo_app/widgets/ignivo_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response _jsonResp(Object data, [int code = 200]) => http.Response(
      jsonEncode(data),
      code,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stitch Demo Components & Sheet System Tests', () {
    testWidgets('IgnivoBrandLogo renders mark and wordmark correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IgnivoBrandLogo.header(excludeFromSemantics: false),
            ),
          ),
        ),
      );

      expect(find.byType(IgnivoBrandLogo), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.bySemanticsLabel('IGNIVO - Smart Safety'), findsOneWidget);
    });

    testWidgets('IgnivoSheet and IgnivoDataRow display data rows and close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showIgnivoSystemSheet(
                    context: ctx,
                    systemName: 'Nhà của tôi',
                    address: 'ignivo-edge.local:8080',
                    isConnected: true,
                    cameraCount: 3,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống của bạn'), findsOneWidget);
      expect(find.text('Nhà của tôi'), findsOneWidget);
      expect(find.text('ignivo-edge.local:8080'), findsOneWidget);
      expect(find.text('Đã kết nối'), findsOneWidget);
      expect(find.text('3 đã cấu hình'), findsOneWidget);
      expect(find.text('Chẩn đoán hệ thống'), findsOneWidget);
      expect(find.text('Đổi kết nối'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống của bạn'), findsNothing);
    });

    testWidgets('showIgnivoDiagnosticsSheet and showIgnivoConfirmSheet render properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showIgnivoDiagnosticsSheet(
                    context: ctx,
                    isConnected: true,
                    isDirectAlertConnected: true,
                    onlineCameras: 2,
                    totalCameras: 3,
                    lastSyncTime: '09:41',
                  );
                },
                child: const Text('Open Diagnostics'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Diagnostics'));
      await tester.pumpAndSettle();

      expect(find.text('Chẩn đoán hệ thống'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('09:41'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Chẩn đoán hệ thống'), findsNothing);
    });

    testWidgets('GuardHomePage displays SỰ CỐ ĐANG ĐƯỢC XỬ LÝ when incident is acknowledged', (tester) async {
      final inc = {
        'id': 105,
        'trigger_type': 'fire',
        'status': 'ack',
        'severity': 'warning',
        'area': 'Phòng khách',
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return _jsonResp({'role': 'OWNER'});
          if (r.url.path.endsWith('/system/info')) return _jsonResp({'hostname': 'pi'});
          if (r.url.path.endsWith('/status')) return _jsonResp({'vision': {'ready': true}});
          if (r.url.path.endsWith('/cameras')) return _jsonResp([]);
          if (r.url.path.endsWith('/incidents/active')) return _jsonResp(inc);
          if (r.url.path.endsWith('/incidents')) return _jsonResp([inc]);
          return _jsonResp({});
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
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SỰ CỐ ĐANG ĐƯỢC XỬ LÝ (#105)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });

    testWidgets('GuardSettingsPage displays user initials and about IGNIVO row', (tester) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return _jsonResp({
              'token': 'valid-test-token',
              'user': {'role': 'OWNER', 'full_name': 'Minh Anh', 'phone_number': '0901234567'},
            });
          }
          if (r.url.path.endsWith('/auth/me')) {
            return _jsonResp({'role': 'OWNER', 'full_name': 'Minh Anh', 'phone_number': '0901234567'});
          }
          return _jsonResp({});
        }),
      );

      final session = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080', systemName: 'Nhà Minh Anh'),
      );
      await session.login(phoneNumber: '0901234567', secretKey: 'k', systemSecretKey: 's');

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
          theme: AppTheme.lightTheme,
          home: GuardSettingsPage(
            sessionController: session,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MA'), findsWidgets);
      expect(find.text('Minh Anh'), findsOneWidget);
      expect(find.text('Giới thiệu IGNIVO'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('IGNIVO · Smart Safety'), 100);
      await tester.pumpAndSettle();
      expect(find.text('IGNIVO · Smart Safety'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      monitoring.stop();
      coordinator.dispose();
      monitoring.dispose();
    });
  });
}
