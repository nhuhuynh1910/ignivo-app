import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/auth/system_login_page.dart';
import 'package:ignivo_app/features/settings/connection_setup_page.dart';
import 'package:ignivo_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResp(Object data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  group('AppEntryGate & Entry Flow Tests', () {
    testWidgets('fresh install opens ConnectionSetupPage without default IP assumption', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const IgnivoApp());
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionSetupPage), findsOneWidget);
      expect(find.text('Kết nối hệ thống IGNIVO'), findsWidgets);
      expect(find.byKey(const Key('setup-guard-url')), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('setup-guard-url'))).controller!.text,
        isEmpty,
      );
    });

    testWidgets('configured profile opens SystemLoginPage with system name and inputs', (
      tester,
    ) async {
      final profile = PiConnectionProfile.fromGuardUrl(
        'http://192.168.1.100:8080',
        systemName: 'Xưởng Mộc A',
      );
      SharedPreferences.setMockInitialValues({
        PiConnectionProfile.prefProfileKey: jsonEncode(profile.toJson()),
      });

      await tester.pumpWidget(const IgnivoApp());
      await tester.pumpAndSettle();

      expect(find.byType(SystemLoginPage), findsOneWidget);
      expect(find.text('Xưởng Mộc A'), findsOneWidget);
      expect(find.text('http://192.168.1.100:8080'), findsOneWidget);
      expect(find.byKey(const Key('phone')), findsOneWidget);
      expect(find.byKey(const Key('secret')), findsOneWidget);
      expect(find.byKey(const Key('system-secret')), findsOneWidget);
      expect(find.byKey(const Key('change-connection-link')), findsOneWidget);

      // Verify tapping "Đổi kết nối" navigates to ConnectionSetupPage
      await tester.tap(find.byKey(const Key('change-connection-link')));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionSetupPage), findsOneWidget);
    });

    testWidgets('successful login via Guard auth proxy transitions to monitoring shell', (
      tester,
    ) async {
      final profile = PiConnectionProfile.fromGuardUrl(
        'http://pi-test:8080',
        systemName: 'Trang trại B',
      );
      SharedPreferences.setMockInitialValues({
        PiConnectionProfile.prefProfileKey: jsonEncode(profile.toJson()),
      });

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'token': 'valid-test-token', 'user': {'role': 'OWNER'}});
          }
          if (r.url.path.endsWith('/auth/me')) {
            return jsonResp({'id': 1, 'role': 'OWNER', 'full_name': 'Nguyễn Chủ'});
          }
          if (r.url.path.endsWith('/system/info')) {
            return jsonResp({'hostname': 'pi-box', 'device_id': 'box-123'});
          }
          if (r.url.path.endsWith('/status')) {
            return jsonResp({'vision': {'ready': true, 'total_ai_fps': 15.0}});
          }
          if (r.url.path.endsWith('/incidents') || r.url.path.endsWith('/cameras')) {
            return jsonResp([]);
          }
          return jsonResp({});
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: profile,
      );

      await tester.pumpWidget(IgnivoApp(
        sessionController: controller,
        authenticatedBuilder: (context, c) => Scaffold(
          body: Center(
            child: Text('SHELL GIÁM SÁT: ${c.fullName} (${c.role})'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SystemLoginPage), findsOneWidget);

      await tester.enterText(find.byKey(const Key('phone')), '0901234567');
      await tester.enterText(find.byKey(const Key('secret')), 'pass123');
      await tester.enterText(find.byKey(const Key('system-secret')), 'syskey456');

      await tester.tap(find.byKey(const Key('login-submit-btn')));
      await tester.pumpAndSettle();

      // Controller must be authenticated
      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser!['role'], 'OWNER');
      expect(controller.deviceId, 'box-123');
      expect(find.byType(SystemLoginPage), findsNothing);
      expect(find.text('SHELL GIÁM SÁT: Nguyễn Chủ (OWNER)'), findsOneWidget);
    });

    testWidgets('invalid login credentials displays friendly error banner and keeps user on login page', (
      tester,
    ) async {
      final profile = PiConnectionProfile.fromGuardUrl(
        'http://pi-test:8080',
        systemName: 'Kho C',
      );
      SharedPreferences.setMockInitialValues({
        PiConnectionProfile.prefProfileKey: jsonEncode(profile.toJson()),
      });

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'detail': 'Sai số điện thoại hoặc mật khẩu'}, 401);
          }
          return jsonResp({}, 404);
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: profile,
      );

      await tester.pumpWidget(IgnivoApp(sessionController: controller));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('phone')), '0901234567');
      await tester.enterText(find.byKey(const Key('secret')), 'wrong-pass');
      await tester.enterText(find.byKey(const Key('system-secret')), 'syskey456');

      await tester.tap(find.byKey(const Key('login-submit-btn')));
      await tester.pumpAndSettle();

      expect(controller.isAuthenticated, isFalse);
      expect(find.byType(SystemLoginPage), findsOneWidget);
      expect(find.textContaining('Sai số điện thoại hoặc mật khẩu'), findsOneWidget);
    });
  });
}
