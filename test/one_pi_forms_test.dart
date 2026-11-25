import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/fireguard/people_page.dart';
import 'package:ignivo_app/features/fireguard/eye_events_page.dart';
import 'package:ignivo_app/features/fireguard/pi_camera_page.dart';

http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<FireguardApiService> guardFor(
  Future<http.Response> Function(http.Request) handler, {
  String role = 'OWNER',
}) async {
  final api = FireguardApiService(
    client: MockClient(
      (r) async => r.url.path == '/api/v1/emergency/auth/me'
          ? json({'role': role})
          : handler(r),
    ),
  );
  await api.setBaseUrl('http://127.0.0.1:8080');
  await api.setAuthToken('test');
  await api.getCurrentUser();
  return api;
}

Future<FireeyeApiService> eyeFor(
  Future<http.Response> Function(http.Request) handler, {
  String role = 'OWNER',
}) async {
  final eye = FireeyeApiService(
    fireguard: FireguardApiService(),
    client: MockClient(
      (r) async =>
          r.url.path == '/api/auth/me' ? json({'role': role}) : handler(r),
    ),
  );
  await eye.useToken('test');
  return eye;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'face registration sheet requires consent; withdrawal needs confirmation and removes person',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final people = <Map<String, dynamic>>[];
      var posts = 0, deletes = 0;
      final api = await guardFor((r) async {
        if (r.url.path == '/api/v1/emergency/faces/watch/status') {
          return json({'available': true, 'running': false});
        }
        if (r.url.path == '/api/v1/emergency/faces/people') {
          return json({'success': true, 'data': people});
        }
        if (r.url.path == '/api/v1/emergency/cameras') {
          return json([]);
        }
        if (r.url.path == '/api/v1/emergency/faces/register-camera') {
          posts++;
          expect(r.body, contains('name="consent"'));
          expect(r.body, contains('true'));
          people.add({
            'id': 1,
            'name': 'Lan',
            'role': 'Family',
            'group_tag': 'FAMILY',
            'consented_at': '2026-10-15',
          });
          return json({'success': true}, 201);
        }
        if (r.method == 'DELETE' &&
            r.url.path == '/api/v1/emergency/faces/people/1') {
          deletes++;
          people.clear();
          return json({'success': true});
        }
        fail('Unexpected ${r.method} ${r.url.path}');
      });

      await tester.pumpWidget(MaterialApp(home: PeoplePage(api: api)));
      await tester.pumpAndSettle();

      // Open registration bottom sheet
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      final register = find.widgetWithText(FilledButton, 'Đăng ký khuôn mặt');
      expect(tester.widget<FilledButton>(register).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('person-name')), 'Lan');
      await tester.tap(find.text('Chụp từ Camera Pi'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('face-consent')));
      await tester.tap(find.byKey(const Key('face-consent')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(register);
      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(posts, 1);

      expect(find.text('Lan'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa hồ sơ và rút lại đồng ý'));
      await tester.pumpAndSettle();
      expect(deletes, 0);

      await tester.tap(find.text('Xóa và ngừng đối chiếu'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Đã đăng ký (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OPERATOR sees people in read-only mode without mutation controls', (
    tester,
  ) async {
    final api = await guardFor((r) async {
      if (r.url.path.endsWith('/faces/people')) {
        return json({'success': true, 'data': []});
      }
      if (r.url.path.endsWith('/cameras')) return json([]);
      return json({'available': true, 'running': false});
    }, role: 'OPERATOR');

    await tester.pumpWidget(MaterialApp(home: PeoplePage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Đăng ký'), findsNothing);
    expect(
      tester.widget<Switch>(find.byType(Switch)).onChanged,
      isNull,
    );
  });

  testWidgets('USER role is blocked by BR-24 access notice', (tester) async {
    final api = await guardFor((_) async => json({}), role: 'USER');
    await tester.pumpWidget(MaterialApp(home: PeoplePage(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('không có quyền truy cập dữ liệu sinh trắc học'),
      findsOneWidget,
    );
  });

  testWidgets('FaceEventsPage loads FireGuard face events and opens detail', (
    tester,
  ) async {
    final api = await guardFor((r) async {
      if (r.url.path == '/api/v1/emergency/faces/events') {
        return json([
          {
            'id': 9,
            'event_type': 'KNOWN_PERSON',
            'area': 'Cổng chính',
            'person_name': 'Lan',
            'confidence': 0.91,
            'message': 'Nhận diện khuôn mặt đã đăng ký: Lan',
            'created_at': '2026-10-15T08:00:00',
          },
        ]);
      }
      return json({});
    });

    await tester.pumpWidget(MaterialApp(home: FaceEventsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhận diện khuôn mặt đã đăng ký: Lan'));
    await tester.pumpAndSettle();
    expect(find.text('Lan'), findsOneWidget);
    expect(
      find.textContaining('chỉ phục vụ xác minh'),
      findsOneWidget,
    );
  });

  testWidgets(
    'PTZ release is queued after start, including a slow start response',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final commands = <String>[];
      final start = Completer<http.Response>();
      final eye = await eyeFor((r) async {
        if (r.url.path.endsWith('/camera')) {
          return json({
            'online': true,
            'status': 'valid',
            'ptz': true,
            'binding': {
              'guard_device_id': 'pi',
              'guard_camera_id': 2,
              'source_revision': 'rev',
            },
          });
        }
        final action = jsonDecode(r.body)['action'] as String;
        commands.add(action);
        return action == 'left' ? start.future : json({'success': true});
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PiCameraPage(
            eye: eye,
            guard: eye.fireguard,
            deviceId: 'pi',
            camera: const {'id': 2, 'name': 'Bếp', 'source_revision': 'rev'},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Trái')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      expect(commands, ['left']);
      start.complete(json({'success': true}));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(commands, ['left', 'stop']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
