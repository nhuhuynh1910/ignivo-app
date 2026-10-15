import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/fireguard/pi_camera_page.dart';

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('FireeyeApiService sends sourceRevision and unbinds', () async {
    final calls = <String>[];
    final eye = await eyeFor((r) async {
      calls.add('${r.method} ${r.url.path}?${r.url.query}');
      if (r.method == 'PUT') {
        final body = jsonDecode(r.body);
        expect(body['source_revision'], 'rev-1');
        return jsonResp({'success': true});
      }
      if (r.method == 'DELETE') {
        expect(r.url.path, '/api/integration/camera');
        return jsonResp({'success': true});
      }
      if (r.method == 'POST' && r.url.path == '/api/integration/ptz') {
        final body = jsonDecode(r.body);
        expect(body['source_revision'], 'rev-1');
        return jsonResp({'success': true});
      }
      return jsonResp({'ptz': true, 'online': true, 'binding': null});
    });

    await eye.getCameraCapabilities(sourceRevision: 'rev-abc');
    expect(calls.last, contains('source_revision=rev-abc'));

    await eye.bindCamera('pi', 1, sourceRevision: 'rev-1');
    await eye.unbindCamera();
    await eye.ptz('pi', 1, 'up', sourceRevision: 'rev-1');
  });

  testWidgets(
    'PiCameraPage displays warning banner when source_revision is stale',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final eye = await eyeFor((r) async {
        if (r.url.path == '/api/integration/camera') {
          return jsonResp({
            'online': true,
            'status': 'stale',
            'binding': {
              'guard_device_id': 'pi',
              'guard_camera_id': 1,
              'source_revision': 'rev-old-123',
            },
          });
        }
        return jsonResp({'success': true});
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PiCameraPage(
            eye: eye,
            guard: eye.fireguard,
            deviceId: 'pi',
            camera: const {
              'id': 1,
              'name': 'Cổng chính',
              'source_revision': 'rev-new-456',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('Cấu hình luồng camera đã thay đổi (source_revision)'),
        findsOneWidget,
      );
      expect(
        find.text('Liên kết cũ không khớp cấu hình luồng mới.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'PiCameraPage displays relink and unbind buttons when bound',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var deleted = false;
      final eye = await eyeFor((r) async {
        if (r.method == 'DELETE') {
          deleted = true;
          return jsonResp({'success': true});
        }
        if (r.url.path == '/api/integration/camera') {
          return jsonResp({
            'online': true,
            'status': 'valid',
            'binding': {
              'guard_device_id': 'pi',
              'guard_camera_id': 1,
              'source_revision': 'rev-123',
            },
          });
        }
        return jsonResp({'success': true});
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PiCameraPage(
            eye: eye,
            guard: eye.fireguard,
            deviceId: 'pi',
            camera: const {
              'id': 1,
              'name': 'Cổng chính',
              'source_revision': 'rev-123',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Đã liên kết PTZ với camera này.'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
      expect(find.text('Hủy liên kết'), findsOneWidget);

      await tester.tap(find.text('Hủy liên kết'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy liên kết PTZ'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Hủy liên kết'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(deleted, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
