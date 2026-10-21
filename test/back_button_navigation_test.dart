import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/core/models/system_record.dart';
import 'package:ignivo_app/core/services/system_session_manager.dart';
import 'package:ignivo_app/core/services/system_registry_repository.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/systems/systems_page.dart';
import 'package:ignivo_app/navigation/ignivo_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemsPage Back Button Tests', () {
    testWidgets('shows leading back button and triggers onBack when provided', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = SystemRegistryRepository(prefs: prefs);
      final manager = SystemSessionManager(registry: registry, uid: 'test-user');
      await manager.initialize();

      var backCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SystemsPage(
            sessionManager: manager,
            canPop: true,
            onBack: () => backCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });

    testWidgets('does not show leading back button when canGoBack is false', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = SystemRegistryRepository(prefs: prefs);
      final manager = SystemSessionManager(registry: registry, uid: 'test-user');
      await manager.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: SystemsPage(
            sessionManager: manager,
            canPop: false,
            onBack: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsNothing);
    });
  });

  group('IgnivoShell PopScope & Back Tab Navigation Tests', () {
    testWidgets('hardware back from non-zero tab navigates back to tab 0 (Trang chủ)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final sys = SystemRecord(
        systemId: 'test_sys',
        systemName: 'Hệ thống A',
        guardUrl: 'http://localhost:8080',
        role: 'OWNER',
        addedAt: DateTime.now(),
      );
      final controller = SystemSessionController(
        initialProfile: sys.toPiConnectionProfile(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IgnivoShell(
            sessionController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on tab 0: "Trang chủ"
      expect(find.text('Trang chủ'), findsWidgets);

      // Tap on Tab 1: "Camera" in NavigationBar
      final cameraTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Camera'),
      );
      expect(cameraTab, findsOneWidget);
      await tester.tap(cameraTab);
      await tester.pumpAndSettle();

      // Verify PopScope canPop is false when on tab 1
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsWidgets);
      final popScope = tester.widget<PopScope>(popScopeFinder.first);
      expect(popScope.canPop, isFalse);

      // Simulate back invocation
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();

      // Should now be back at tab 0, canPop should be true
      final updatedPopScope = tester.widget<PopScope>(popScopeFinder.first);
      expect(updatedPopScope.canPop, isTrue);
    });
  });
}
