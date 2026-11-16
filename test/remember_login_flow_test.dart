import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/models/system_record.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/system_registry_repository.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/core/services/system_session_manager.dart';
import 'package:ignivo_app/features/auth/login_page.dart';
import 'package:ignivo_app/features/auth/system_login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Kiểm tra lưu đăng nhập hệ thống IGNIVO', () {
    test('SystemSessionController.restoreTokenSession succeeds and authenticates', () async {
      final api = FireguardApiService(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({
                'id': 1,
                'phone_number': '0901234567',
                'role': 'OWNER',
                'full_name': 'Nguyễn Văn Chủ',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200, headers: {'content-type': 'application/json'});
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://192.168.1.100:8080',
          systemName: 'Nhà Chính',
        ),
      );

      expect(controller.isAuthenticated, isFalse);

      final ok = await controller.restoreTokenSession('saved_valid_token_xyz');
      expect(ok, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.fullName, 'Nguyễn Văn Chủ');
      expect(controller.role, 'OWNER');
    });

    testWidgets('SystemLoginPage pre-fills saved phone number from SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ignivo_saved_phone_number': '0912345678',
      });

      final controller = SystemSessionController(
        api: FireguardApiService(),
        initialProfile: PiConnectionProfile.fromGuardUrl(
          'http://192.168.1.100:8080',
          systemName: 'Nhà Chính',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SystemLoginPage(
            sessionController: controller,
            canPop: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final phoneFinder = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == '0912345678',
      );
      expect(phoneFinder, findsOneWidget);
    });

    testWidgets('LoginPage pre-fills saved email when remember email is enabled', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ignivo_saved_login_email': 'testuser@ignivo.com',
        'ignivo_remember_login_email': true,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final emailFinder = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'testuser@ignivo.com',
      );
      expect(emailFinder, findsOneWidget);
      expect(find.text('Ghi nhớ tài khoản'), findsOneWidget);
    });

    test('SystemSessionManager auto-restores active system session on initialize', () async {
      final prefs = await SharedPreferences.getInstance();
      final registry = SystemRegistryRepository(prefs: prefs);
      const uid = 'uid_remember_test';

      final system = SystemRecord(
        systemId: 'sys_01',
        systemName: 'Hệ thống Auto Login',
        guardUrl: 'http://mock-pi:8080',
        addedAt: DateTime.now(),
      );

      await registry.saveSystem(uid, system, token: 'saved_jwt_secret');
      await registry.setActiveSystemId(uid, system.systemId);

      final manager = SystemSessionManager(
        registry: registry,
        uid: uid,
        controllerFactory: (rec, {savedToken}) {
          final api = FireguardApiService(
            client: MockClient((req) async {
              if (req.url.path.endsWith('/auth/me')) {
                return http.Response(
                  jsonEncode({
                    'id': 1,
                    'phone_number': '0909999888',
                    'role': 'ADMIN',
                    'full_name': 'Kỹ Thuật Viên',
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response('{}', 200, headers: {'content-type': 'application/json'});
            }),
          );
          if (savedToken != null) api.setAuthToken(savedToken);
          return SystemSessionController(
            api: api,
            initialProfile: rec.toPiConnectionProfile(),
          );
        },
      );

      await manager.initialize();

      expect(manager.activeController, isNotNull);
      expect(manager.activeController!.isAuthenticated, isTrue);
      expect(manager.activeController!.fullName, 'Kỹ Thuật Viên');
      expect(manager.activeController!.role, 'ADMIN');
    });
  });
}
