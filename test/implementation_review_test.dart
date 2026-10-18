import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/features/fireguard/camera_editor_page.dart';
import 'package:ignivo_app/features/fireguard/incident_page.dart';
import 'package:ignivo_app/features/fireguard/pi_camera_page.dart';
import 'alarm_coordinator_test.dart' show FakeRealtimeService, MockAlertFeedbackAdapter;

http.Response jsonResp(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<FireeyeApiService> eyeFor(
  Future<http.Response> Function(http.Request) handler, {
  String role = 'OWNER',
}) async {
  final eye = FireeyeApiService(
    fireguard: FireguardApiService(),
    client: MockClient(
      (r) async =>
          r.url.path == '/api/auth/me' ? jsonResp({'role': role}) : handler(r),
    ),
  );
  await eye.useToken('test');
  return eye;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FireguardApiService api;
  late FakeRealtimeService realtime;
  late MockAlertFeedbackAdapter feedback;
  late IncidentAlertCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FireguardApiService();
    await api.setAuthToken('test-session');
    realtime = FakeRealtimeService(api);
    feedback = MockAlertFeedbackAdapter();
    coordinator = IncidentAlertCoordinator(api: api, realtime: realtime, feedbackAdapter: feedback);
  });

  tearDown(() {
    coordinator.dispose();
    realtime.dispose();
  });

  test('ACK received from another device must stop the active siren', () async {
    realtime.emit('incident.analyzed', {'id': 1, 'status': 'notifying', 'severity': 'high'});
    await Future<void>.delayed(Duration.zero);
    expect(feedback.isSirenActive, isTrue);
    realtime.emit('incident.updated', {'id': 1, 'status': 'acknowledged', 'severity': 'high'});
    await Future<void>.delayed(Duration.zero);
    expect(feedback.isSirenActive, isFalse, reason: 'ACK must terminate audible alert');
  });

  test('access token rotation must preserve a silenced incident', () async {
    final incident = {'id': 2, 'status': 'notifying', 'severity': 'high'};
    realtime.emit('incident.analyzed', incident);
    await Future<void>.delayed(Duration.zero);
    coordinator.silenceAlarm();
    await api.setAuthToken('refreshed-token', preserveUser: true);
    coordinator.syncActiveIncidents([incident]);
    expect(feedback.isSirenActive, isFalse, reason: 'Token refresh must not erase silence state');
  });

  group('Gói 5: PTZ capability & permission restrictions', () {
    testWidgets('PTZ controls are locked and show reason for STAFF role without move request', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var ptzCommandsSent = 0;
      final eye = await eyeFor((r) async {
        if (r.url.path == '/api/integration/ptz') {
          ptzCommandsSent++;
          return jsonResp({'success': true});
        }
        if (r.url.path == '/api/integration/camera') {
          return jsonResp({
            'online': true,
            'status': 'valid',
            'binding': {
              'guard_device_id': 'pi',
              'guard_camera_id': 1,
              'source_revision': 'rev-1',
            },
          });
        }
        return jsonResp({'success': true});
      }, role: 'STAFF');

      await tester.pumpWidget(
        MaterialApp(
          home: PiCameraPage(
            eye: eye,
            guard: eye.fireguard,
            deviceId: 'pi',
            camera: const {
              'id': 1,
              'name': 'Camera Cổng',
              'source_revision': 'rev-1',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Chỉ chủ sở hữu hoặc quản trị viên được điều khiển PTZ.'), findsOneWidget);
      expect(find.text('Trái'), findsNothing);
      expect(ptzCommandsSent, 0);
    });

    testWidgets('PTZ shows offline status when camera offline and prevents move', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var ptzCommandsSent = 0;
      final eye = await eyeFor((r) async {
        if (r.url.path == '/api/integration/ptz') {
          ptzCommandsSent++;
          return jsonResp({'success': true});
        }
        if (r.url.path == '/api/integration/camera') {
          return jsonResp({
            'online': false,
            'status': 'valid',
            'binding': {
              'guard_device_id': 'pi',
              'guard_camera_id': 1,
              'source_revision': 'rev-1',
            },
          });
        }
        return jsonResp({'success': true});
      }, role: 'OWNER');

      await tester.pumpWidget(
        MaterialApp(
          home: PiCameraPage(
            eye: eye,
            guard: eye.fireguard,
            deviceId: 'pi',
            camera: const {
              'id': 1,
              'name': 'Camera Cổng',
              'source_revision': 'rev-1',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Camera FireEye đang mất kết nối. Chưa thể điều khiển.'), findsOneWidget);
      expect(find.text('Trái'), findsNothing);
      expect(ptzCommandsSent, 0);
    });

    testWidgets('PTZ shows unsupported status when ptz capability is false', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final eye = await eyeFor((r) async {
        if (r.url.path == '/api/integration/camera') {
          return jsonResp({
            'online': true,
            'ptz': false,
            'status': 'unsupported',
            'binding': null,
          });
        }
        return jsonResp({'success': true});
      }, role: 'OWNER');

      await tester.pumpWidget(
        MaterialApp(
          home: PiCameraPage(
            eye: eye,
            guard: eye.fireguard,
            deviceId: 'pi',
            camera: const {
              'id': 1,
              'name': 'Camera Cố định',
              'source_revision': 'rev-1',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Camera này không hỗ trợ điều khiển PTZ.'), findsOneWidget);
      expect(find.text('Camera này không hỗ trợ điều khiển xoay/zoom (PTZ).'), findsOneWidget);
    });
  });

  group('Gói 5: Camera editor security', () {
    testWidgets('GuardCameraEditor does not expose raw RTSP or passwords and sends partial update', (tester) async {
      Map<String, dynamic>? updatedBody;
      final guardApi = FireguardApiService(
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            updatedBody = jsonDecode(r.body) as Map<String, dynamic>;
            return jsonResp({'success': true});
          }
          return jsonResp({});
        }),
      );
      await guardApi.setAuthToken('test');
      guardApi.currentUser = {'role': 'ADMIN'};

      await tester.pumpWidget(
        MaterialApp(
          home: GuardCameraEditor(
            api: guardApi,
            camera: const {
              'id': 10,
              'name': 'Kho Vải',
              'area': 'Tầng 1',
              'source': 'rtsp://admin:super_secret_pwd@192.168.1.50/stream',
              'ai_fps': 10.0,
              'enabled': true,
              'detect_enabled': true,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('super_secret_pwd'), findsNothing);
      expect(find.textContaining('rtsp://'), findsNothing);

      await tester.ensureVisible(find.text('Lưu camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu camera'));
      await tester.pumpAndSettle();

      expect(updatedBody, isNotNull);
      expect(updatedBody!.containsKey('source'), isFalse);
      expect(updatedBody!['name'], 'Kho Vải');
      expect(updatedBody!['area'], 'Tầng 1');
      expect(updatedBody!['ai_fps'], 10.0);
    });
  });

  group('Gói 4: Incident page AI dismissal and evidence flow', () {
    testWidgets('displays AI dismissal guidance banner when status is ai_dismissed', (tester) async {
      final guardApi = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/image/snap.jpg')) {
            return http.Response.bytes(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), 200);
          }
          return jsonResp({
            'id': 55,
            'camera_id': 2,
            'camera_name': 'Khu Bếp',
            'area': 'Bếp chính',
            'status': 'ai_dismissed',
            'severity': 'low',
            'trigger_type': 'smoke',
            'created_at': '2026-10-15T10:00:00',
            'analysis_image_url': 'http://pi:8080/api/v1/emergency/incidents/55/image/snap.jpg',
            'analysis': {
              'model': 'gemini-1.5-flash',
              'summary_vi': 'Khói hơi nước từ nồi nấu, không phải đám cháy thực sự.',
            },
          });
        }),
      );
      await guardApi.setAuthToken('test');

      await tester.pumpWidget(
        MaterialApp(
          home: FireguardIncidentPage(
            incidentId: 55,
            api: guardApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI bổ sung nhận định không phải cháy; cần kiểm tra bằng chứng'), findsOneWidget);
      expect(find.text('Khu Bếp'), findsOneWidget);
      expect(find.textContaining('Bếp chính'), findsOneWidget);
      expect(find.text('Nhận xử lý • Dừng gọi tiếp'), findsOneWidget);
      expect(find.text('Đã xử lý xong'), findsOneWidget);
      expect(find.text('Báo nhầm'), findsOneWidget);
    });
  });
}
