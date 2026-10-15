// Local visual QA with synthetic data; no Pi credentials or network writes.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/theme/app_theme.dart';
import 'package:ignivo_app/features/fireguard/fireguard_page.dart';
import 'package:ignivo_app/features/fireguard/people_page.dart';
import 'package:ignivo_app/features/fireguard/eye_events_page.dart';
import 'package:ignivo_app/features/fireguard/pi_camera_page.dart';
import 'fireguard_page_test.dart' show TestRealtime;

void main() {
  testWidgets('capture mobile FireGuard tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const fontDir = String.fromEnvironment('GUARD_FONT_DIR');
    if (fontDir.isNotEmpty) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            File(
              '$fontDir/roboto-regular.ttf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              '$fontDir/materialicons-regular.otf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await icons.load();
      });
    }
    SharedPreferences.setMockInitialValues({});
    final api = FireguardApiService(
      client: MockClient((r) async {
        final data = switch (r.url.path.split('/emergency').last) {
          '/auth/me' => {'role': 'ADMIN', 'full_name': 'Quản trị viên'},
          '/system/info' => {'hostname': 'Raspberry Pi 5', 'cpu_temp_c': 57.3},
          '/status' => {
            'detection_source': 'local',
            'vision': {
              'ready': true,
              'detector': 'hailo',
              'model': 'fire_1cls',
              'person_model': 'coco_yolov6n',
              'model_classes': ['fire', 'human'],
              'total_ai_fps': 0,
            },
            'gemini_configured': true,
            'gemini_model': 'gemini-2.5-flash',
            'stringee_configured': false,
            'stringee_missing': ['STRINGEE_FROM_NUMBER'],
            'call_provider': 'stringee',
            'location_configured': false,
            'family_contacts': 0,
            'fire_dept_contacts': 0,
          },
          '/cameras' => [
            {
              'id': 2,
              'name': 'Camera phòng khách',
              'area': 'Tầng 1',
              'source_type': 'rtsp',
              'enabled': true,
              'detect_enabled': true,
              'ai_fps': 8,
              'status': {
                'online': false,
                'state': 'SAFE',
                'ai_fps': 0,
                'capture_fps': 0,
                'resolution': [2304, 1296],
                'error': 'Không mở được nguồn camera',
                'scores': {'fire': 0, 'smoke': 0, 'human': 0},
              },
            },
          ],
          '/incidents' => [
            {
              'id': 1,
              'camera_name': 'Camera phòng khách',
              'camera_id': 2,
              'trigger_type': 'FIRE',
              'status': 'notified',
              'severity': 'high',
              'is_simulation': true,
              'created_at': '2026-10-14 10:30:00',
              'analysis': {
                'summary_vi':
                    'Phát hiện lửa và khói trong phòng. Kiểm tra ngay khu vực camera giám sát.',
              },
            },
          ],
          '/incidents/active' => null,
          _ => <String, dynamic>{},
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await api.setBaseUrl('http://100.95.189.60:8080');
    final eye = FireeyeApiService(
      fireguard: api,
      client: MockClient((r) async {
        final data = switch (r.url.path) {
          '/api/auth/me' => {'role': 'OWNER'},
          '/api/faces/people' => {
            'data': [
              {
                'id': 1,
                'name': 'Người tham gia mẫu',
                'consented_at': '2026-10-15',
              },
            ],
          },
          '/api/faces/watch/status' => {'available': true, 'running': false},
          '/api/events' => {
            'data': [
              {
                'id': 1,
                'event_type': 'KNOWN_PERSON',
                'message': 'Đã đối chiếu người tham gia mẫu',
                'created_at': '2026-10-15 10:30:00',
              },
            ],
          },
          '/api/integration/camera' => {
            'online': true,
            'ptz': true,
            'binding': {'guard_device_id': 'preview-pi', 'guard_camera_id': 2},
          },
          _ => <String, dynamic>{},
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await eye.useToken('preview-only');
    final boundaryKey = GlobalKey();
    final previewTheme = AppTheme.lightTheme.copyWith(
      appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
        titleTextStyle: AppTheme.lightTheme.appBarTheme.titleTextStyle
            ?.copyWith(fontFamily: 'Roboto'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppTheme.lightTheme.elevatedButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: previewTheme,
          debugShowCheckedModeBanner: false,
          home: FireguardPage(api: api, eye: eye, realtime: TestRealtime(api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/fireguard-preview').create(recursive: true);
        await File(
          'build/fireguard-preview/${['live', 'incidents', 'cameras', 'settings'][i]}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    final pages = <String, Widget>{
      'people': PeoplePage(eye: eye),
      'eye-events': EyeEventsPage(eye: eye),
      'ptz': PiCameraPage(
        eye: eye,
        guard: api,
        deviceId: 'preview-pi',
        camera: const {'id': 2, 'name': 'Camera phòng khách'},
      ),
    };
    for (final page in pages.entries) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: previewTheme,
            debugShowCheckedModeBanner: false,
            home: page.value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/fireguard-preview/${page.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
