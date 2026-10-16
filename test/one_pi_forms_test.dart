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
    'face registration requires consent; withdrawal needs confirmation and removes person',
    (tester) async {
      final people = <Map<String, dynamic>>[];
      var posts = 0, deletes = 0;
      final eye = await eyeFor((r) async {
        if (r.url.path == '/api/faces/watch/status') {
          return json({'available': true, 'running': false});
        }
        if (r.url.path == '/api/faces/people') return json({'data': people});
        if (r.url.path == '/api/faces/register-camera') {
          posts++;
          expect(r.body, contains('name="consent"'));
          expect(r.body, contains('true'));
          people.add({'id': 1, 'name': 'Lan', 'consented_at': '2026-10-15'});
          return json({'success': true}, 201);
        }
        if (r.method == 'DELETE') {
          deletes++;
          people.clear();
          return json({'success': true});
        }
        fail('Unexpected ${r.method} ${r.url.path}');
      });
      await tester.pumpWidget(MaterialApp(home: PeoplePage(eye: eye)));
      await tester.pumpAndSettle();
      final register = find.widgetWithText(FilledButton, 'Đăng ký khuôn mặt');
      expect(tester.widget<FilledButton>(register).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('person-name')), 'Lan');
      await tester.ensureVisible(find.text('Chụp từ camera trên Pi'));
      await tester.tap(find.text('Chụp từ camera trên Pi'));
      await tester.ensureVisible(find.byKey(const Key('face-consent')));
      await tester.tap(find.byKey(const Key('face-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(register);
      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(posts, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Xóa hồ sơ và rút lại đồng ý'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
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
  testWidgets('read-only user sees people without mutation controls', (
    tester,
  ) async {
    final eye = await eyeFor(
      (r) async => r.url.path.endsWith('/people')
          ? json({'data': []})
          : json({'available': true, 'running': false}),
      role: 'STAFF',
    );
    await tester.pumpWidget(MaterialApp(home: PeoplePage(eye: eye)));
    await tester.pumpAndSettle();
    expect(find.text('Đăng ký khuôn mặt'), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
  });
  testWidgets('FireEye history opens event detail and marks this event read', (
    tester,
  ) async {
    final reads = <String>[];
    final eye = await eyeFor((r) async {
      if (r.method == 'POST') {
        reads.add(r.url.path);
        return json({'success': true});
      }
      return json({
        'data': [
          {
            'id': 9,
            'event_type': 'KNOWN_PERSON',
            'message': 'Lan đã có mặt',
            'created_at': '2026-10-15',
          },
        ],
      });
    });
    await tester.pumpWidget(MaterialApp(home: EyeEventsPage(eye: eye)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Lan đã có mặt'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(reads, ['/api/notifications/9/read']);
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
