import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/fireguard/eye_events_page.dart';
import 'package:ignivo_app/features/fireguard/person_detail_sheet.dart';

http.Response jsonResp(Object data, [int status = 200]) => http.Response(
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
    testWidgets('Renders person info and loads multi-angle samples',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/faces/people/1/samples') {
          return jsonResp({
            'success': true,
            'samples': [
              {
                'id': 101,
                'person_id': 1,
                'image_path': '/static/faces/frontal.jpg',
                'angle_type': 'FRONTAL',
                'quality_score': 0.92,
                'created_at': '2026-11-01',
              },
              {
                'id': 102,
                'person_id': 1,
                'image_path': '/static/faces/left.jpg',
                'angle_type': 'LEFT_PROFILE',
                'quality_score': 0.85,
                'created_at': '2026-11-01',
              },
            ],
          });
        }
        return jsonResp({});
      });

      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: client,
      );
      await eye.configure('http://127.0.0.1:8000');

      final person = {
        'id': 1,
        'name': 'Nguyễn Văn A',
        'group_tag': 'FAMILY',
        'consented_at': '2026-10-30 08:30:00',
        'avatar_path': '',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonDetailSheet(
              person: person,
              eye: eye,
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
      expect(find.text('Nghiêng trái'), findsOneWidget);
      expect(find.text('Nét: 92%'), findsOneWidget);
      expect(find.text('Nét: 85%'), findsOneWidget);
    });

    testWidgets('Triggers onDelete callback when user confirms deletion',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return jsonResp({'role': 'OWNER'});
          }
          return jsonResp({'samples': []});
        }),
      );
      await eye.configure('http://127.0.0.1:8000');
      await eye.useToken('test_token');

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
              eye: eye,
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

  group('EyeEventsPage UNKNOWN_PERSON security actions', () {
    testWidgets(
        'Renders intruder action buttons for UNKNOWN_PERSON and triggers alarm',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool alarmTriggered = false;

      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((request) async {
          if (request.url.path == '/api/events') {
            return jsonResp({
              'data': [
                {
                  'id': 88,
                  'event_type': 'UNKNOWN_PERSON',
                  'message': 'Đã phát hiện người lạ',
                  'created_at': '2026-11-03 12:00:00',
                  'snapshot_path': '',
                }
              ]
            });
          }
          if (request.url.path == '/api/audio/alarm/start') {
            alarmTriggered = true;
            return jsonResp({'success': true});
          }
          if (request.url.path.startsWith('/api/notifications/')) {
            return jsonResp({'success': true});
          }
          return jsonResp({});
        }),
      );
      await eye.configure('http://127.0.0.1:8000');

      await tester.pumpWidget(
        MaterialApp(
          home: EyeEventsPage(eye: eye),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the unknown person event card to open detail
      await tester.tap(find.text('Chưa đối chiếu được người'));
      await tester.pumpAndSettle();

      expect(
        find.text('Phát hiện đối tượng chưa xác định danh tính'),
        findsOneWidget,
      );
      expect(find.text('Đăng ký vào hệ thống'), findsOneWidget);
      expect(find.text('Hú còi loa Pi 5'), findsOneWidget);

      // Tap alarm button
      await tester.tap(find.text('Hú còi loa Pi 5'));
      await tester.pumpAndSettle();

      expect(alarmTriggered, isTrue);
      expect(
        find.text('Đã kích hoạt còi hú báo động trên loa Pi 5!'),
        findsOneWidget,
      );
    });
  });
}
