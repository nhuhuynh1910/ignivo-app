import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/settings/edge_connection_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  http.Response json(Object data, [int code = 200]) =>
      http.Response(jsonEncode(data), code);
  Future<void> login(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('phone')), '0912345678');
    await tester.enterText(find.byKey(const Key('secret')), 'secret');
    await tester.enterText(find.byKey(const Key('system-secret')), 'system');
    await tester.scrollUntilVisible(
      find.text('Đăng nhập hệ thống'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Đăng nhập hệ thống'));
    await tester.pumpAndSettle();
  }

  for (final guardOnline in [false, true]) {
    testWidgets('monitor access requires FireGuard online=$guardOnline', (
      tester,
    ) async {
      final guard = FireguardApiService(
        client: MockClient((_) async {
          if (!guardOnline) throw http.ClientException('offline');
          return json({'role': 'OWNER'});
        }),
      );
      final eye = FireeyeApiService(
        fireguard: guard,
        client: MockClient(
          (r) async => json(
            r.url.path.endsWith('/login')
                ? {'token': 'abc'}
                : {'role': 'OWNER'},
          ),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: EdgeConnectionPage(api: eye)));
      await tester.pumpAndSettle();
      await login(tester);
      await tester.scrollUntilVisible(
        find.textContaining('FireEye: đã đăng nhập'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      if (guardOnline) {
        await tester.scrollUntilVisible(
          find.text('Mở tổng quan hệ thống'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Mở tổng quan hệ thống'), findsOneWidget);
      } else {
        expect(find.textContaining('FireGuard chưa sẵn sàng'), findsOneWidget);
        expect(find.text('Mở tổng quan hệ thống'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid credentials do not unlock monitoring', (tester) async {
    final eye = FireeyeApiService(
      fireguard: FireguardApiService(),
      client: MockClient((_) async => json({'detail': 'Invalid'}, 401)),
    );
    await tester.pumpWidget(MaterialApp(home: EdgeConnectionPage(api: eye)));
    await tester.pumpAndSettle();
    await login(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Đăng nhập FireEye thất bại'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mở tổng quan hệ thống'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
