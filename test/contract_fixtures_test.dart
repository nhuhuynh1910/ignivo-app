import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/fireguard/incident_page.dart';
import 'package:ignivo_app/features/fireguard/monitor_widgets.dart';

http.Response jsonResp(Object data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Contract & Fixtures Tests', () {
    test('parses fireguard_status.json fixture accurately', () async {
      final file = File('test/fixtures/fireguard_status.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/system/info')) {
            return jsonResp({'hostname': json['hostname'], 'cpu_temp_c': json['cpu_temp_c']});
          }
          if (r.url.path.endsWith('/status')) {
            return jsonResp(json);
          }
          return jsonResp({});
        }),
      );
      await api.setAuthToken('token');

      final status = await api.getSystemStatus();
      expect(status, isNotNull);
      expect(status!['hostname'], 'ignivo-pi5');
      expect(status['hailo_ready'], isTrue);
      expect(status['total_ai_fps'], 16.2);
      expect(status['call_provider'], 'stringee');
      expect(status['location_configured'], isTrue);
    });

    test('parses fireguard_incident.json fixture and presentation helpers safely', () async {
      final file = File('test/fixtures/fireguard_incident.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/incidents/101')) {
            return jsonResp(json);
          }
          return jsonResp({});
        }),
      );
      await api.setAuthToken('token');

      final incident = await api.getIncidentDetail(101);
      expect(incident, isNotNull);
      expect(incident!['id'], 101);
      expect(incident['status'], 'notifying');
      expect(incident['severity'], 'critical');
      expect(incident['analysis']['is_real_fire'], isTrue);

      expect(IncidentPresentationHelper.cameraName(incident), 'Kho A - Tầng 1');
      expect(IncidentPresentationHelper.areaText(incident), 'Kho nguyên liệu');
      expect(IncidentPresentationHelper.severityLabel(incident['severity']), 'Cực kỳ nguy hiểm');
      expect(IncidentPresentationHelper.triggerLabel(incident['trigger_type']), 'Phát hiện Lửa');
      expect(incidentStatusLabel(incident['status']), 'Đang gọi điện');
    });

    test('parses fireguard_cameras.json fixture safely', () async {
      final file = File('test/fixtures/fireguard_cameras.json');
      expect(file.existsSync(), isTrue);
      final list = jsonDecode(file.readAsStringSync()) as List;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/cameras')) {
            return jsonResp(list);
          }
          return jsonResp([]);
        }),
      );
      await api.setAuthToken('token');

      final cameras = await api.getCameras();
      expect(cameras.length, 1);
      final cam = cameras.first;
      expect(cam['name'], 'Camera Kho A');
      expect(cam['source_revision'], 'rev-101');
      expect(cameraHealth(cam), 'Chưa phát hiện');
    });

    test('missing fields and error responses handled without crashes', () async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/incidents/999')) {
            return http.Response(jsonEncode({'detail': 'Không tìm thấy sự cố'}), 404);
          }
          if (r.url.path.endsWith('/incidents/active')) {
            return http.Response('null', 200);
          }
          return http.Response('{}', 500);
        }),
      );
      await api.setAuthToken('token');

      final active = await api.getActiveIncident();
      expect(active, isNull);

      expect(() => api.getIncidentDetail(999), throwsA(isA<FireguardException>()));

      // Empty map fallback checks on Presentation helpers
      expect(IncidentPresentationHelper.cameraName({}), 'Camera #null');
      expect(IncidentPresentationHelper.areaText({}), 'Chưa xác định khu vực');
      expect(IncidentPresentationHelper.severityLabel(null), 'Đang đánh giá mức độ');
      expect(incidentStatusLabel(null), 'null');
    });

    test('parses fireguard_auth_login and fireguard_auth_me fixtures correctly', () async {
      final loginFile = File('test/fixtures/fireguard_auth_login.json');
      final meFile = File('test/fixtures/fireguard_auth_me.json');
      expect(loginFile.existsSync(), isTrue);
      expect(meFile.existsSync(), isTrue);

      final loginJson = jsonDecode(loginFile.readAsStringSync()) as Map<String, dynamic>;
      final meJson = jsonDecode(meFile.readAsStringSync()) as Map<String, dynamic>;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            expect(r.method, 'POST');
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            expect(body['phone_number'], '0912345678');
            expect(body['secret_key'], 'secret123');
            expect(body['system_secret_key'], 'syskey456');
            return jsonResp(loginJson);
          }
          if (r.url.path.endsWith('/auth/me')) {
            expect(r.headers['authorization'], 'Bearer mock-fireguard-jwt-token-xyz123');
            return jsonResp(meJson);
          }
          return jsonResp({}, 404);
        }),
      );

      final success = await api.login(
        phoneNumber: '0912345678',
        secretKey: 'secret123',
        systemSecretKey: 'syskey456',
      );

      expect(success, isTrue);
      expect(api.authToken, 'mock-fireguard-jwt-token-xyz123');
      expect(api.currentUser, isNotNull);
      expect(api.currentUser!['role'], 'OWNER');
      expect(api.currentUser!['full_name'], 'Nguyễn Văn A');
    });

    test('parses fireguard_system_info fixture with device_id', () async {
      final sysFile = File('test/fixtures/fireguard_system_info.json');
      expect(sysFile.existsSync(), isTrue);
      final sysJson = jsonDecode(sysFile.readAsStringSync()) as Map<String, dynamic>;

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/system/info')) {
            return jsonResp(sysJson);
          }
          return jsonResp({}, 404);
        }),
      );
      await api.setAuthToken('mock-token');

      final info = await api.getSystemInfo();
      expect(info, isNotNull);
      expect(info!['hostname'], 'ignivo-pi5');
      expect(info['device_id'], 'pi5-edge-sn-7890');
    });

    test('handles 401, 403, and 503 error fixtures predictably', () async {
      final err401 = jsonDecode(File('test/fixtures/fireguard_error_401.json').readAsStringSync());
      final err403 = jsonDecode(File('test/fixtures/fireguard_error_403.json').readAsStringSync());
      final err503 = jsonDecode(File('test/fixtures/fireguard_error_503.json').readAsStringSync());

      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return jsonResp(err401, 401);
          }
          if (r.url.path.endsWith('/contacts') && r.method == 'POST') {
            return jsonResp(err403, 403);
          }
          if (r.url.path.endsWith('/system/info')) {
            return jsonResp({'hostname': 'pi'});
          }
          if (r.url.path.endsWith('/status')) {
            return jsonResp(err503, 503);
          }
          return jsonResp({}, 404);
        }),
      );

      // Login 401 returns false
      final loginOk = await api.login(
        phoneNumber: '0912345678',
        secretKey: 'wrong',
        systemSecretKey: 'wrong',
      );
      expect(loginOk, isFalse);
      expect(api.lastError, contains('Sai số điện thoại'));

      // Protected 403 returns null and sets lastError with backend detail
      await api.setAuthToken('token');
      final contact = await api.createContact(name: 'Test', phone: '0912345678');
      expect(contact, isNull);
      expect(api.lastError, contains('Không có quyền'));

      // Status 503 returns null and sets lastError with 503 detail
      final status = await api.getSystemStatus();
      expect(status, isNull);
      expect(api.lastError, contains('Không kết nối được FireEye'));
    });
  });
}

