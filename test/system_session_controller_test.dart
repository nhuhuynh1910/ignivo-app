import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResp(Object data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SystemSessionController Unit Tests', () {
    test('initializes as unconfigured when no profile exists in preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = SystemSessionController();
      await controller.initialize(prefs);

      expect(controller.isConfigured, isFalse);
      expect(controller.status, SessionStatus.unconfigured);
      expect(controller.isAuthenticated, isFalse);
    });

    test('initializes as unauthenticated when configured profile exists', () async {
      final profile = PiConnectionProfile.fromGuardUrl(
        'http://pi-farm:8080',
        systemName: 'Trại Nấm A',
      );
      final prefs = await SharedPreferences.getInstance();
      await profile.save(prefs);

      final controller = SystemSessionController();
      await controller.initialize(prefs);

      expect(controller.isConfigured, isTrue);
      expect(controller.systemName, 'Trại Nấm A');
      expect(controller.guardUrl, 'http://pi-farm:8080');
      expect(controller.status, SessionStatus.unauthenticated);
      expect(controller.isAuthenticated, isFalse);
    });

    test('login succeeds only when /auth/me verifies returned token', () async {
      final prefs = await SharedPreferences.getInstance();
      var meCalled = false;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'token': 'jwt-abc-123', 'user': {'role': 'OWNER'}});
          }
          if (r.url.path.endsWith('/auth/me')) {
            meCalled = true;
            expect(r.headers['authorization'], 'Bearer jwt-abc-123');
            return jsonResp({
              'id': 10,
              'username': '0912345678',
              'full_name': 'Lê Văn C',
              'role': 'OWNER',
            });
          }
          if (r.url.path.endsWith('/system/info')) {
            return jsonResp({'device_id': 'hw-pi5-9988'});
          }
          return jsonResp({}, 404);
        }),
      );

      final profile = PiConnectionProfile.fromGuardUrl('http://pi-farm:8080');
      await profile.save(prefs);

      final controller = SystemSessionController(api: api, initialProfile: profile);
      final ok = await controller.login(
        phoneNumber: '0912345678',
        secretKey: 'pass',
        systemSecretKey: 'sys',
        prefs: prefs,
      );

      expect(ok, isTrue);
      expect(meCalled, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.role, 'OWNER');
      expect(controller.fullName, 'Lê Văn C');
      expect(controller.isOwnerOrAdmin, isTrue);
      expect(controller.canHandleIncidents, isTrue);
      expect(controller.deviceId, 'hw-pi5-9988');

      // Verify device_id was persisted to profile in SharedPreferences
      final reloaded = await PiConnectionProfile.load(prefs);
      expect(reloaded.deviceId, 'hw-pi5-9988');
    });

    test('login fails and rejects token if /auth/me returns 401 or empty', () async {
      final prefs = await SharedPreferences.getInstance();

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'token': 'invalid-token', 'user': {}});
          }
          if (r.url.path.endsWith('/auth/me')) {
            return jsonResp({'detail': 'Token signature invalid'}, 401);
          }
          return jsonResp({}, 404);
        }),
      );

      final profile = PiConnectionProfile.fromGuardUrl('http://pi-farm:8080');
      final controller = SystemSessionController(api: api, initialProfile: profile);

      final ok = await controller.login(
        phoneNumber: '0912345678',
        secretKey: 'pass',
        systemSecretKey: 'sys',
        prefs: prefs,
      );

      expect(ok, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.status, SessionStatus.unauthenticated);
      expect(api.authToken, isNull);
    });

    test('role RBAC: USER can handle incidents but is not owner/admin', () async {
      final prefs = await SharedPreferences.getInstance();

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'token': 'jwt-user-token'});
          }
          if (r.url.path.endsWith('/auth/me')) {
            return jsonResp({
              'id': 11,
              'username': '0988776655',
              'role': 'USER',
            });
          }
          return jsonResp({});
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );

      await controller.login(
        phoneNumber: '0988776655',
        secretKey: 'p',
        systemSecretKey: 's',
        prefs: prefs,
      );

      expect(controller.isAuthenticated, isTrue);
      expect(controller.role, 'USER');
      expect(controller.isOwnerOrAdmin, isFalse);
      expect(controller.canHandleIncidents, isTrue);
    });

    test('logout clears in-memory credentials and resets session status', () async {
      final prefs = await SharedPreferences.getInstance();
      var logoutCalled = false;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp({'token': 'token-to-logout'});
          }
          if (r.url.path.endsWith('/auth/me')) {
            return jsonResp({'role': 'USER'});
          }
          if (r.url.path.endsWith('/auth/logout')) {
            logoutCalled = true;
            return jsonResp({'ok': true});
          }
          return jsonResp({});
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );

      await controller.login(
        phoneNumber: '1',
        secretKey: '2',
        systemSecretKey: '3',
        prefs: prefs,
      );
      expect(controller.isAuthenticated, isTrue);

      final revBefore = controller.sessionRevision;
      await controller.logout();

      expect(logoutCalled, isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.status, SessionStatus.unauthenticated);
      expect(api.authToken, isNull);
      expect(controller.currentUser, isNull);
      expect(controller.sessionRevision, greaterThan(revBefore));
    });

    test('updateProfile resets session if host changes', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = SystemSessionController(
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi-old:8080'),
      );
      await controller.api.setAuthToken('token-old');

      final newProfile = PiConnectionProfile.fromGuardUrl('http://pi-new:8080');
      await controller.updateProfile(newProfile, prefs);

      expect(controller.guardUrl, 'http://pi-new:8080');
      expect(controller.api.authToken, isNull);
      expect(controller.status, SessionStatus.unauthenticated);
    });

    test('handleSessionExpired sets sessionExpired state and clears token', () {
      final controller = SystemSessionController(
        initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
      );
      controller.api.setAuthToken('expired-token');

      controller.handleSessionExpired('Token signature expired');

      expect(controller.status, SessionStatus.sessionExpired);
      expect(controller.api.authToken, isNull);
      expect(controller.lastError, 'Token signature expired');
    });
  });
}
