import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/system_session_controller.dart';
import 'package:ignivo_app/features/activity/guard_activity_page.dart';
import 'package:ignivo_app/features/camera/guard_cameras_page.dart';
import 'package:ignivo_app/features/fireguard/eye_events_page.dart';
import 'package:ignivo_app/features/fireguard/monitoring_controller.dart';
import 'package:ignivo_app/features/fireguard/person_detail_sheet.dart';

import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;
import 'fireguard_page_test.dart' show TestRealtime;

http.Response jsonResp(Object? data, [int status = 200]) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FireeyeApiService Audio & Edge Alarm Methods', () {
    test('startEdgeAlarm and stopEdgeAlarm send proper requests', () async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/audio/alarm/start') {
          return jsonResp({'success': true, 'message': 'Đã kích hoạt còi'});
        }
        if (request.url.path == '/api/audio/alarm/stop') {
          return jsonResp({'success': true, 'message': 'Đã tắt còi'});
        }
        if (request.url.path == '/api/audio/status') {
          return jsonResp({'is_alarm_active': false, 'volume': 0.8});
        }
        return jsonResp({'detail': 'Not found'}, 404);
      });

      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: client,
      );
      await eye.configure('http://127.0.0.1:8000');

      await eye.startEdgeAlarm(duration: 5.0);
      expect(requests, contains('POST /api/audio/alarm/start'));

      await eye.stopEdgeAlarm();
      expect(requests, contains('POST /api/audio/alarm/stop'));

      final status = await eye.getAudioStatus();
      expect(status['is_alarm_active'], isFalse);
      expect(status['volume'], equals(0.8));
    });
  });

  group('PersonDetailSheet UI Widget Tests', () {
    testWidgets('Renders person info and loads multi-angle samples via FireGuard',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/emergency/faces/people/1/samples') {
          return jsonResp({
            'success': true,
            'samples': [
              {
                'id': 101,
                'person_id': 1,
                'image_path': '',
                'angle_type': 'FRONTAL',
                'quality_score': 0.92,
                'created_at': '2026-11-01',
              },
              {
                'id': 102,
                'person_id': 1,
                'image_path': '',
                'angle_type': 'MASK',
                'quality_score': 0.85,
                'created_at': '2026-11-01',
              },
            ],
          });
        }
        return jsonResp({});
      });

      final api = FireguardApiService(client: client);
      await api.setBaseUrl('http://127.0.0.1:8080');
      await api.setAuthToken('test_token');

      final person = {
        'id': 1,
        'name': 'Nguyễn Văn A',
        'role': 'Operator',
        'group_tag': 'FAMILY',
        'consented_at': '2026-10-30 08:30:00',
        'avatar_path': '',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonDetailSheet(
              person: person,
              api: api,
              onAddSample: () async {},
              onDelete: () async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ khuôn mặt'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Gia đình'), findsOneWidget);
      expect(find.text('Chính diện'), findsOneWidget);
      expect(find.text('Đeo khẩu trang'), findsOneWidget);
      expect(find.text('Nét: 92%'), findsOneWidget);
      expect(find.text('Nét: 85%'), findsOneWidget);
    });

    testWidgets('Triggers onDelete callback for OWNER when confirmed',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FireguardApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/emergency/auth/me') {
            return jsonResp({'role': 'OWNER'});
          }
          return jsonResp({'samples': []});
        }),
      );
      await api.setBaseUrl('http://127.0.0.1:8080');
      await api.setAuthToken('test_token');
      await api.getCurrentUser();

      bool deleted = false;
      final person = {
        'id': 2,
        'name': 'Trần Văn B',
        'group_tag': 'STAFF',
        'consented_at': '2026-10-25',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonDetailSheet(
              person: person,
              api: api,
              onAddSample: () async {},
              onDelete: () async {
                deleted = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteBtn = find.text('Xóa hồ sơ & Rút lại sự đồng thuận');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });
  });

  group('FaceEventsPage BR-06 neutral verification behavior', () {
    testWidgets(
        'Renders neutral verification state for UNKNOWN_PERSON without alarm trigger',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FireguardApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/emergency/auth/me') {
            return jsonResp({'role': 'OWNER'});
          }
          if (request.url.path == '/api/v1/emergency/faces/events') {
            return jsonResp([
              {
                'id': 88,
                'event_type': 'UNKNOWN_PERSON',
                'area': 'Cổng trước',
                'confidence': 0.32,
                'message': 'Khuôn mặt chưa khớp danh sách đăng ký (Cần xác minh)',
                'created_at': '2026-11-03 12:00:00',
                'snapshot_url': '',
              }
            ]);
          }
          return jsonResp({});
        }),
      );
      await api.setBaseUrl('http://127.0.0.1:8080');
      await api.setAuthToken('test_token');
      await api.getCurrentUser();

      await tester.pumpWidget(
        MaterialApp(
          home: FaceEventsPage(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CẦN XÁC MINH'), findsOneWidget);
      await tester.tap(find.text('Khuôn mặt chưa khớp danh sách đăng ký (Cần xác minh)'));
      await tester.pumpAndSettle();

      expect(find.text('Cần xác minh danh tính'), findsOneWidget);
      expect(find.text('Mở hồ sơ để đăng ký người quen'), findsOneWidget);
      // BR-06: Face events must never trigger fire siren/alarm
      expect(find.text('Hú còi loa Pi 5'), findsNothing);
    });
  });

  group('Contextual Face Entry Points RBAC Tests', () {
    testWidgets('Shows FaceQuickAccessCard for OPERATOR and hides for USER',
        (tester) async {
      Future<void> pumpForRole(String role) async {
        final api = FireguardApiService(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/auth/me')) return jsonResp({'role': role});
            if (r.url.path.endsWith('/system/info')) {
              return jsonResp({'hostname': 'pi'});
            }
            if (r.url.path.endsWith('/status')) {
              return jsonResp({'vision': {'ready': true}});
            }
            if (r.url.path.endsWith('/cameras') ||
                r.url.path.endsWith('/incidents')) {
              return jsonResp([]);
            }
            if (r.url.path.endsWith('/incidents/active')) return jsonResp(null);
            if (r.url.path.endsWith('/faces/events')) {
              return jsonResp([
                {
                  'id': 51,
                  'event_type': 'KNOWN_PERSON',
                  'area': 'Cổng',
                  'person_name': 'An',
                  'confidence': 0.9,
                  'message': 'Nhận diện khuôn mặt đã đăng ký: An',
                  'created_at': '2026-11-25T10:00:00',
                },
              ]);
            }
            return jsonResp({});
          }),
        );
        final session = SystemSessionController(
          api: api,
          initialProfile: PiConnectionProfile.fromGuardUrl('http://pi:8080'),
        );
        await api.setAuthToken('tok');
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
              body: Column(
                children: [
                  Expanded(
                    child: GuardCamerasPage(
                      monitoringController: monitoring,
                      sessionController: session,
                    ),
                  ),
                  Expanded(
                    child: GuardActivityPage(
                      monitoringController: monitoring,
                      sessionController: session,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        if (role == 'OPERATOR') {
          expect(find.text('Hồ sơ gương mặt'), findsOneWidget);
          expect(find.text('Sự cố cháy'), findsOneWidget);
          expect(find.text('Nhận diện gương mặt'), findsOneWidget);

          // Switch Cảnh báo tab to Face mode
          await tester.tap(find.text('Nhận diện gương mặt'));
          await tester.pumpAndSettle();
          expect(find.text('Nhận diện khuôn mặt đã đăng ký: An'), findsOneWidget);
          expect(find.text('Hồ sơ'), findsOneWidget);
        } else {
          expect(find.text('Hồ sơ gương mặt'), findsNothing);
          expect(find.text('Nhận diện gương mặt'), findsNothing);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        monitoring.stop();
        coordinator.dispose();
        monitoring.dispose();
      }

      await pumpForRole('OPERATOR');
      await pumpForRole('USER');
    });
  });
}
