import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/models/system_record.dart';
import 'package:ignivo_app/core/services/pi_grant_service.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 - SystemRecord RBAC Helpers', () {
    test('role getters return correct permissions for each role', () {
      final owner = SystemRecord(
        systemId: 's1',
        systemName: 'Sys Owner',
        guardUrl: 'http://pi:8080',
        role: 'OWNER',
        addedAt: DateTime.now(),
      );
      expect(owner.canOperate, isTrue);
      expect(owner.canManageMembers, isTrue);
      expect(owner.isViewer, isFalse);
      expect(owner.roleDisplayName, 'Chủ sở hữu');

      final admin = SystemRecord(
        systemId: 's2',
        systemName: 'Sys Admin',
        guardUrl: 'http://pi:8080',
        role: 'ADMIN',
        addedAt: DateTime.now(),
      );
      expect(admin.canOperate, isTrue);
      expect(admin.canManageMembers, isTrue);
      expect(admin.isViewer, isFalse);
      expect(admin.roleDisplayName, 'Quản trị viên');

      final operator = SystemRecord(
        systemId: 's3',
        systemName: 'Sys Operator',
        guardUrl: 'http://pi:8080',
        role: 'OPERATOR',
        addedAt: DateTime.now(),
      );
      expect(operator.canOperate, isTrue);
      expect(operator.canManageMembers, isFalse);
      expect(operator.isViewer, isFalse);
      expect(operator.roleDisplayName, 'Vận hành');

      final viewer = SystemRecord(
        systemId: 's4',
        systemName: 'Sys Viewer',
        guardUrl: 'http://pi:8080',
        role: 'VIEWER',
        addedAt: DateTime.now(),
      );
      expect(viewer.canOperate, isFalse);
      expect(viewer.canManageMembers, isFalse);
      expect(viewer.isViewer, isTrue);
      expect(viewer.roleDisplayName, 'Chỉ xem');
    });
  });

  group('Milestone 2 - PiGrantService', () {
    test('exchangeGrantOnPi sends grant and receives tokens', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/v1/auth/exchange-grant')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['grant_token'], 'valid_grant_jwt_token');
          return http.Response(
            jsonEncode({
              'token': 'local_jwt_access_token',
              'refresh_token': 'local_jwt_refresh_token',
              'user': {
                'id': 'cloud_user_1',
                'username': 'cloud_user_1',
                'role': 'OPERATOR',
                'is_cloud': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = PiGrantService(httpClient: mockClient);
      final res = await service.exchangeGrantOnPi(
        guardUrl: 'http://192.168.1.100:8080',
        grantToken: 'valid_grant_jwt_token',
        installationId: 'inst_123',
      );

      expect(res['token'], 'local_jwt_access_token');
      expect(res['user']['role'], 'OPERATOR');
    });

    test('signClaimChallengeOnPi calls challenge signing endpoint on Pi', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/v1/auth/sign-claim-challenge')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['challenge'], 'nonce_challenge_123');
          return http.Response(
            jsonEncode({
              'device_id': 'pi-box-01',
              'signature': 'ed25519_sig_hex_999',
              'public_key_pem': '-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----',
              'fingerprint': 'sha256_fp',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = PiGrantService(httpClient: mockClient);
      final res = await service.signClaimChallengeOnPi(
        guardUrl: 'http://192.168.1.100:8080',
        challenge: 'nonce_challenge_123',
      );

      expect(res['device_id'], 'pi-box-01');
      expect(res['signature'], 'ed25519_sig_hex_999');
    });
  });

  group('Milestone 2 - SystemSessionController RBAC Constraints', () {
    test('VIEWER role cannot handle incidents', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final api = FireguardApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({'token': 'viewer_token', 'user': {'role': 'VIEWER'}}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({
                'id': 'u1',
                'username': 'viewer1',
                'role': 'VIEWER',
                'is_first_login': 0,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('OK', 200);
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: SystemRecord(
          systemId: 'sys_viewer',
          systemName: 'Viewer System',
          guardUrl: 'http://pi:8080',
          role: 'VIEWER',
          addedAt: DateTime.now(),
        ).toPiConnectionProfile(),
      );

      await controller.login(
        phoneNumber: '0911223344',
        secretKey: 'p',
        systemSecretKey: 's',
        prefs: prefs,
      );

      expect(controller.isAuthenticated, isTrue);
      expect(controller.role, 'VIEWER');
      expect(controller.isViewer, isTrue);
      expect(controller.canOperate, isFalse);
      expect(controller.canHandleIncidents, isFalse);
    });

    test('OPERATOR role can handle incidents but is not admin', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final api = FireguardApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({'token': 'op_token', 'user': {'role': 'OPERATOR'}}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({
                'id': 'u2',
                'username': 'operator1',
                'role': 'OPERATOR',
                'is_first_login': 0,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('OK', 200);
        }),
      );

      final controller = SystemSessionController(
        api: api,
        initialProfile: SystemRecord(
          systemId: 'sys_op',
          systemName: 'Operator System',
          guardUrl: 'http://pi:8080',
          role: 'OPERATOR',
          addedAt: DateTime.now(),
        ).toPiConnectionProfile(),
      );

      await controller.login(
        phoneNumber: '0911223355',
        secretKey: 'p',
        systemSecretKey: 's',
        prefs: prefs,
      );

      expect(controller.isAuthenticated, isTrue);
      expect(controller.role, 'OPERATOR');
      expect(controller.isViewer, isFalse);
      expect(controller.isOwnerOrAdmin, isFalse);
      expect(controller.canOperate, isTrue);
      expect(controller.canHandleIncidents, isTrue);
    });
  });
}
