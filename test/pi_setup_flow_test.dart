import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/settings/edge_connection_page.dart';
import 'package:ignivo_app/features/settings/pi_setup_page.dart';

http.Response jsonResp(Object data, [int code = 200]) =>
    http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PiConnectionProfile', () {
    test('derives :8000 and :8080 from single host', () {
      final p1 = PiConnectionProfile.fromHost('192.168.1.50');
      expect(p1.piHost, '192.168.1.50');
      expect(p1.eyeUrl, 'http://192.168.1.50:8000');
      expect(p1.guardUrl, 'http://192.168.1.50:8080');
      expect(p1.isCustomAdvanced, isFalse);

      final p2 = PiConnectionProfile.fromHost('https://pi.lan');
      expect(p2.eyeUrl, 'https://pi.lan:8000');
      expect(p2.guardUrl, 'https://pi.lan:8080');
    });

    test('preserves custom advanced URLs', () {
      final p = PiConnectionProfile.fromCustomUrls(
        systemName: 'Xưởng',
        eyeUrl: 'http://my-pi:9000',
        guardUrl: 'http://my-pi:9080',
      );
      expect(p.isCustomAdvanced, isTrue);
      expect(p.eyeUrl, 'http://my-pi:9000');
      expect(p.guardUrl, 'http://my-pi:9080');
    });

    test('persists and loads from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = PiConnectionProfile.fromHost('10.0.0.99', systemName: 'Kho hàng');
      await p.save(prefs);

      final loaded = await PiConnectionProfile.load(prefs);
      expect(loaded.systemName, 'Kho hàng');
      expect(loaded.piHost, '10.0.0.99');
      expect(loaded.eyeUrl, 'http://10.0.0.99:8000');
      expect(loaded.guardUrl, 'http://10.0.0.99:8080');
    });
  });

  group('PiSetupPage', () {
    testWidgets('allows editing host and returns updated profile', (tester) async {
      PiConnectionProfile? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<PiConnectionProfile>(
                  ctx,
                  MaterialPageRoute(builder: (_) => const PiSetupPage()),
                );
              },
              child: const Text('Open Setup'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Thiết lập kết nối Pi'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('setup-system-name')), 'Văn phòng HN');
      await tester.enterText(find.byKey(const Key('setup-pi-host')), '192.168.1.120');

      await tester.tap(find.text('Lưu cấu hình kết nối'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.systemName, 'Văn phòng HN');
      expect(result!.piHost, '192.168.1.120');
      expect(result!.eyeUrl, 'http://192.168.1.120:8000');
      expect(result!.guardUrl, 'http://192.168.1.120:8080');
    });
  });

  group('EdgeConnectionPage Gói 2 Flow', () {
    testWidgets('degraded monitoring state allows retry without re-authenticating', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var guardOnline = false;
      final guard = FireguardApiService(
        client: MockClient((_) async {
          if (!guardOnline) throw http.ClientException('503 Service Unavailable');
          return jsonResp({'role': 'OWNER'});
        }),
      );

      final eye = FireeyeApiService(
        fireguard: guard,
        client: MockClient(
          (r) async => jsonResp(
            r.url.path.endsWith('/login') ? {'token': 'valid-tok'} : {'role': 'OWNER'},
          ),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: EdgeConnectionPage(api: eye)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('phone')), '0912345678');
      await tester.enterText(find.byKey(const Key('secret')), 'mypass');
      await tester.enterText(find.byKey(const Key('system-secret')), 'syskey');

      // Password visibility toggle test
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(find.text('Đăng nhập hệ thống'));
      await tester.pumpAndSettle();

      // State is degraded because guard is offline
      expect(find.textContaining('Đã đăng nhập — chưa kết nối giám sát'), findsOneWidget);
      expect(find.text('Thử lại kết nối giám sát'), findsOneWidget);

      // Now guard comes online
      guardOnline = true;
      await tester.tap(find.text('Thử lại kết nối giám sát'));
      await tester.pumpAndSettle();

      // Successfully transitions to ready without password re-entry
      expect(find.text('Mở tổng quan hệ thống'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
