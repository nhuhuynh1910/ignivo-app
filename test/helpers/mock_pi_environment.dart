import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/models/system_record.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';

class MockPiEnvironment {
  MockPiEnvironment() {
    _initClients();
  }

  static const String alphaGuardUrl = 'http://mock-pi-alpha:8080';
  static const String betaGuardUrl = 'http://mock-pi-beta:8080';

  static const String alphaToken = 'token_alpha_owner_secret';
  static const String betaToken = 'token_beta_staff_secret';

  final List<http.Request> alphaReceivedRequests = [];
  final List<http.Request> betaReceivedRequests = [];

  bool alphaHasActiveEmergency = true;

  late final http.Client alphaHttpClient;
  late final http.Client betaHttpClient;

  late final FireguardApiService apiAlpha;
  late final FireguardApiService apiBeta;

  final SystemRecord recordAlpha = SystemRecord(
    systemId: 'sys_alpha_01',
    systemName: 'Hệ thống Pi A (Nhà Riêng)',
    guardUrl: alphaGuardUrl,
    location: '123 Đường Số 1, Quận 1',
    role: 'OWNER',
    isOwner: true,
    addedAt: DateTime(2026, 1, 1),
    status: 'online',
  );

  final SystemRecord recordBeta = SystemRecord(
    systemId: 'sys_beta_02',
    systemName: 'Hệ thống Pi B (Kho Hàng)',
    guardUrl: betaGuardUrl,
    location: '456 Khu Công Nghiệp B',
    role: 'STAFF',
    isOwner: false,
    addedAt: DateTime(2026, 1, 2),
    status: 'online',
  );

  void _initClients() {
    alphaHttpClient = MockClient((request) async {
      alphaReceivedRequests.add(request);
      final path = request.url.path;

      if (path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': alphaToken,
            'user': {'id': 1, 'role': 'OWNER', 'full_name': 'Chủ Nhà A'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/auth/me')) {
        return http.Response(
          jsonEncode({'id': 1, 'role': 'OWNER', 'full_name': 'Chủ Nhà A'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/system/info')) {
        return http.Response(
          jsonEncode({'hostname': 'pi-alpha', 'device_id': 'box-alpha-101'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/status')) {
        return http.Response(
          jsonEncode({
            'vision': {'ready': true, 'total_ai_fps': 15.0},
            'direct_alert': {'connected': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/cameras')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Sân trước Nhà A',
              'rtsp_url': 'rtsp://mock-cam-1/live',
              'status': {'online': true},
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/incidents')) {
        return http.Response(
          jsonEncode(alphaHasActiveEmergency
              ? [
                  {
                    'id': 1,
                    'incident_id': 1,
                    'camera_id': 1,
                    'status': 'analyzing',
                    'severity': 'critical',
                    'title': 'Cảnh báo cháy tầng 1',
                    'created_at': '2026-10-21T18:00:00Z',
                  }
                ]
              : []),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/incidents/1')) {
        return http.Response(
          jsonEncode({
            'id': 1,
            'incident_id': 1,
            'camera_id': 1,
            'status': 'analyzing',
            'severity': 'critical',
            'title': 'Cảnh báo cháy tầng 1',
            'evidence': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });

    betaHttpClient = MockClient((request) async {
      betaReceivedRequests.add(request);
      final path = request.url.path;

      if (path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': betaToken,
            'user': {'id': 2, 'role': 'STAFF', 'full_name': 'Nhân Viên B'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/auth/me')) {
        return http.Response(
          jsonEncode({'id': 2, 'role': 'STAFF', 'full_name': 'Nhân Viên B'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/system/info')) {
        return http.Response(
          jsonEncode({'hostname': 'pi-beta', 'device_id': 'box-beta-202'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/status')) {
        return http.Response(
          jsonEncode({
            'vision': {'ready': true, 'total_ai_fps': 12.5},
            'direct_alert': {'connected': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/cameras')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Kho hàng B',
              'rtsp_url': 'rtsp://mock-cam-beta-1/live',
              'status': {'online': true},
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/incidents')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'incident_id': 1,
              'camera_id': 1,
              'status': 'resolved',
              'severity': 'low',
              'title': 'Khói bụi đã xử lý',
              'created_at': '2026-10-21T17:00:00Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/incidents/1')) {
        return http.Response(
          jsonEncode({
            'id': 1,
            'incident_id': 1,
            'camera_id': 1,
            'status': 'resolved',
            'severity': 'low',
            'title': 'Khói bụi đã xử lý',
            'evidence': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });

    apiAlpha = FireguardApiService(client: alphaHttpClient);
    apiAlpha.setBaseUrl(alphaGuardUrl);
    apiAlpha.setAuthToken(alphaToken);

    apiBeta = FireguardApiService(client: betaHttpClient);
    apiBeta.setBaseUrl(betaGuardUrl);
    apiBeta.setAuthToken(betaToken);
  }

  SystemSessionController createControllerForAlpha() {
    return SystemSessionController(
      api: apiAlpha,
      initialProfile: recordAlpha.toPiConnectionProfile(),
    );
  }

  SystemSessionController createControllerForBeta() {
    return SystemSessionController(
      api: apiBeta,
      initialProfile: recordBeta.toPiConnectionProfile(),
    );
  }
}
