import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/fireguard/camera_editor_page.dart';
import 'package:ignivo_app/features/fireguard/escalation_page.dart';
import 'package:ignivo_app/features/fireguard/monitor_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const camera = {
    'id': 2,
    'name': 'Camera bếp',
    'area': 'Bếp',
    'source_type': 'rtsp',
    'source': 'rtsp://admin:***@camera/live',
    'ai_fps': 8,
    'enabled': true,
    'detect_enabled': true,
    'rotate': 90,
    'fire_threshold': .7,
  };
  for (final code in [200, 403]) {
    testWidgets(
      'camera partial update preserves secret and advanced settings; HTTP $code',
      (tester) async {
        Map<String, dynamic>? sent;
        final api = FireguardApiService(
          client: MockClient((r) async {
            expectSync(r.method, 'PUT');
            expectSync(r.url.path, '/api/v1/emergency/cameras/2');
            sent = jsonDecode(r.body);
            return http.Response(
              jsonEncode(code == 200 ? camera : {'detail': 'Forbidden'}),
              code,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        await api.setAuthToken('test');
        api.currentUser = {'role': 'ADMIN'};
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GuardCameraEditor(api: api, camera: camera),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Lưu camera'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu camera'));
        await tester.pumpAndSettle();
        expect(sent, isNotNull);
        expect(sent!.containsKey('source'), isFalse);
        expect(sent!.containsKey('rotate'), isFalse);
        expect(sent!.containsKey('fire_threshold'), isFalse);
        if (code == 200) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();
          expect(find.text('Open'), findsOneWidget, reason: api.lastError);
        } else {
          expect(find.text('Forbidden'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'escalation saves displayed values and preserves current hidden voice settings',
    (tester) async {
      var reads = 0;
      Map<String, dynamic>? sent;
      final api = FireguardApiService(
        client: MockClient((r) async {
          expectSync(r.url.path, '/api/v1/emergency/settings/escalation');
          if (r.method == 'PUT') {
            sent = jsonDecode(r.body);
            return http.Response(r.body, 200);
          }
          reads++;
          return http.Response(
            jsonEncode({
              'call_family': true,
              'call_fire_dept': true,
              'trigger_on_smoke': true,
              'fire_dept_min_severity': 'high',
              'fire_dept_delay_s': 60,
              'retry_after_s': 90,
              'max_rounds': 2,
              'voice': reads == 1 ? 'banmai' : 'leminh',
              'speed': 1,
              'loop': 3,
            }),
            200,
          );
        }),
      );
      await api.setAuthToken('test');
      api.currentUser = {'role': 'ADMIN'};
      await tester.pumpWidget(MaterialApp(home: GuardEscalationPage(api: api)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lưu quy tắc'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu quy tắc'));
      await tester.pumpAndSettle();
      expect(sent?['voice'], 'leminh');
      expect(sent?['speed'], 1);
      expect(sent?['loop'], 3);
      expect(sent?['max_rounds'], 2);
      expect(find.text('Đã lưu quy tắc gọi điện.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('non-admin cannot save camera; non-finite FPS is rejected', (
    tester,
  ) async {
    var writes = 0;
    final api = FireguardApiService(
      client: MockClient((_) async {
        writes++;
        return http.Response('{}', 200);
      }),
    );
    await api.setAuthToken('test');
    api.currentUser = {'role': 'USER'};
    await tester.pumpWidget(
      MaterialApp(
        home: GuardCameraEditor(api: api, camera: camera),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lưu camera'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu camera'))
          .onPressed,
      isNull,
    );
    expect(writes, 0);
    api.currentUser = {'role': 'ADMIN'};
    await tester.pumpWidget(
      MaterialApp(
        home: GuardCameraEditor(
          key: const ValueKey('admin'),
          api: api,
          camera: {...camera, 'ai_fps': double.nan},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lưu camera'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu camera'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Nhập số từ 0.5 đến 30'), findsOneWidget);
  });

  testWidgets(
    'offline, zero-FPS and unsupported smoke never appear as fresh safe readings',
    (tester) async {
      expect(
        cameraHealth({
          'status': {'online': true, 'state': 'SAFE', 'ai_fps': 0},
        }),
        'AI chưa có dữ liệu',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CameraTelemetry(
              camera: {
                'enabled': true,
                'detect_enabled': true,
                'status': {
                  'online': false,
                  'state': 'SAFE',
                  'ai_fps': 0,
                  'scores': {'fire': .8, 'smoke': 0, 'human': .2},
                },
              },
              modelClasses: ['fire', 'human'],
            ),
          ),
        ),
      );
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Khói · Model không hỗ trợ'), findsOneWidget);
      expect(find.text('Lửa · Chưa có dữ liệu mới'), findsOneWidget);
      expect(find.textContaining('80%'), findsNothing);
    },
  );
}
