import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/core/services/app_auth_controller.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/multi_system_monitoring_coordinator.dart';
import 'package:ignivo_app/core/services/system_registry_repository.dart';
import 'package:ignivo_app/core/services/system_session_manager.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/systems/systems_page.dart';
import 'package:ignivo_app/navigation/ignivo_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;
import 'helpers/mock_pi_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPiEnvironment env;
  late SystemRegistryRepository registry;
  late SystemSessionManager manager;
  const testUid = 'user_test_uid_999';

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    env = MockPiEnvironment();
    final prefs = await SharedPreferences.getInstance();
    registry = SystemRegistryRepository(prefs: prefs);

    // Save both systems to registry
    await registry.saveSystem(testUid, env.recordAlpha, token: MockPiEnvironment.alphaToken);
    await registry.saveSystem(testUid, env.recordBeta, token: MockPiEnvironment.betaToken);
    await registry.setActiveSystemId(testUid, env.recordAlpha.systemId);

    manager = SystemSessionManager(
      registry: registry,
      uid: testUid,
      controllerFactory: (record, {savedToken}) {
        if (record.systemId == env.recordAlpha.systemId) {
          final c = env.createControllerForAlpha();
          if (savedToken != null) c.api.setAuthToken(savedToken);
          return c;
        } else {
          final c = env.createControllerForBeta();
          if (savedToken != null) c.api.setAuthToken(savedToken);
          return c;
        }
      },
    );

    await manager.initialize();
  });

  tearDown(() {
    manager.dispose();
  });

  group('Tiêu chí 40: Dual Mock Pi Isolation Tests', () {
    test('Scenario 1: Camera ID Collision Isolation (Camera #1 on Alpha vs Beta)', () async {
      // System A is active
      expect(manager.activeSystemId, env.recordAlpha.systemId);
      final controllerAlpha = manager.activeController!;
      final camerasAlpha = await controllerAlpha.api.getCameras();
      expect(camerasAlpha.length, 1);
      expect(camerasAlpha.first['id'], 1);
      expect(camerasAlpha.first['name'], 'Sân trước Nhà A');

      // Switch to System B
      await manager.switchSystem(env.recordBeta.systemId);
      expect(manager.activeSystemId, env.recordBeta.systemId);
      final controllerBeta = manager.activeController!;
      final camerasBeta = await controllerBeta.api.getCameras();
      expect(camerasBeta.length, 1);
      expect(camerasBeta.first['id'], 1);
      expect(camerasBeta.first['name'], 'Kho hàng B');

      // Alpha's controller remains intact
      final alphaAgain = manager.getController(env.recordAlpha.systemId)!;
      final camerasAlpha2 = await alphaAgain.api.getCameras();
      expect(camerasAlpha2.first['name'], 'Sân trước Nhà A');
    });

    test('Scenario 2: Incident ID Collision Isolation (Incident #1 analyzing vs resolved)', () async {
      final controllerAlpha = manager.getController(env.recordAlpha.systemId)!;
      final controllerBeta = manager.getController(env.recordBeta.systemId)!;

      final incidentsAlpha = await controllerAlpha.api.getIncidents();
      final incidentsBeta = await controllerBeta.api.getIncidents();

      expect(incidentsAlpha.first['id'], 1);
      expect(incidentsAlpha.first['status'], 'analyzing');
      expect(incidentsAlpha.first['severity'], 'critical');

      expect(incidentsBeta.first['id'], 1);
      expect(incidentsBeta.first['status'], 'resolved');
      expect(incidentsBeta.first['severity'], 'low');
    });

    test('Scenario 3: Token Bleed Prevention across dual Pi endpoints', () async {
      final controllerAlpha = manager.getController(env.recordAlpha.systemId)!;
      final controllerBeta = manager.getController(env.recordBeta.systemId)!;

      await controllerAlpha.api.getCurrentUser();
      await controllerBeta.api.getCurrentUser();

      // Check all requests captured by Pi Alpha
      for (final req in env.alphaReceivedRequests) {
        expect(req.url.host, 'mock-pi-alpha');
        expect(req.headers['authorization'], 'Bearer ${MockPiEnvironment.alphaToken}');
        expect(req.headers['authorization'], isNot(contains(MockPiEnvironment.betaToken)));
      }

      // Check all requests captured by Pi Beta
      for (final req in env.betaReceivedRequests) {
        expect(req.url.host, 'mock-pi-beta');
        expect(req.headers['authorization'], 'Bearer ${MockPiEnvironment.betaToken}');
        expect(req.headers['authorization'], isNot(contains(MockPiEnvironment.alphaToken)));
      }
    });

    test('Scenario 4: Cross-System Emergency Alert & Dynamic Notification', () async {
      // App active on System B (Kho hàng B)
      await manager.switchSystem(env.recordBeta.systemId);
      expect(manager.activeSystemId, env.recordBeta.systemId);

      final coordinator = MultiSystemMonitoringCoordinator(
        sessionManager: manager,
        pollInterval: const Duration(seconds: 1),
        baseJitter: Duration.zero,
      );

      CrossSystemIncidentAlert? receivedAlert;
      final sub = coordinator.onCrossSystemAlert.listen((alert) {
        receivedAlert = alert;
      });

      // Poll inactive systems (Pi Alpha is inactive and has critical incident #1)
      await coordinator.pollInactiveSystems();
      await pumpEventQueue();

      expect(receivedAlert, isNotNull);
      expect(receivedAlert!.systemId, env.recordAlpha.systemId);
      expect(receivedAlert!.systemName, 'Hệ thống Pi A (Nhà Riêng)');
      expect(receivedAlert!.incidentId, 1);
      expect(receivedAlert!.severity, 'critical');

      // Tapping banner switches back to Alpha
      await manager.switchSystem(receivedAlert!.systemId);
      expect(manager.activeSystemId, env.recordAlpha.systemId);

      await sub.cancel();
      coordinator.dispose();
    });

    testWidgets('UI: SystemsPage displays both systems and switches active system on tap', (
      tester,
    ) async {
      final authController = AppAuthController(
        initialMockUid: testUid,
        initialMockEmail: 'owner@ignivo.test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SystemsPage(
            sessionManager: manager,
            authController: authController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống giám sát'), findsOneWidget);
      expect(find.text('Hệ thống Pi A (Nhà Riêng)'), findsOneWidget);
      expect(find.text('Hệ thống Pi B (Kho Hàng)'), findsOneWidget);
      expect(find.text('ĐANG CHỌN'), findsOneWidget);
      expect(find.text('Chuyển tới'), findsOneWidget);

      // Tap "Chuyển tới" on Pi B
      await tester.tap(find.text('Chuyển tới'));
      await tester.pumpAndSettle();

      expect(manager.activeSystemId, env.recordBeta.systemId);
    });

    testWidgets('UI: IgnivoShell cross-system alert toast banner displays and switches system on tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await manager.switchSystem(env.recordBeta.systemId);
      final activeBeta = manager.activeController!;
      final coordinator = MultiSystemMonitoringCoordinator(
        sessionManager: manager,
        pollInterval: const Duration(seconds: 1),
        baseJitter: Duration.zero,
      );
      final realtime = TestRealtime(activeBeta.api);
      final alertCoordinator = IncidentAlertCoordinator(
        api: activeBeta.api,
        realtime: realtime,
        feedbackAdapter: MockAlertFeedbackAdapter(),
      );
      final monitoring = MonitoringController(
        api: activeBeta.api,
        realtime: realtime,
        coordinator: alertCoordinator,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IgnivoShell(
            sessionController: activeBeta,
            sessionManager: manager,
            coordinator: coordinator,
            monitoringController: monitoring,
          ),
        ),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await coordinator.pollInactiveSystems();
      });
      // 1. Drain microtask so _crossAlertSub fires showSnackBar
      await tester.pump();
      // 2. Advance the SnackBar slide-in animation
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('CẢNH BÁO KHẨN CẤP: Hệ thống Pi A (Nhà Riêng)'),
        findsOneWidget,
      );
      expect(find.text('Chuyển hệ thống'), findsOneWidget);

      await tester.tap(find.text('Chuyển hệ thống'));
      await tester.pump();

      expect(manager.activeSystemId, env.recordAlpha.systemId);

      ScaffoldMessenger.of(tester.element(find.byType(IgnivoShell))).clearSnackBars();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      monitoring.dispose();
      alertCoordinator.dispose();
      coordinator.dispose();
    });
  });
}
