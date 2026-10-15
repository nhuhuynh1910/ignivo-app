import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app opens Pi login with the configured Tailscale endpoints', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnivoApp());
    await tester.pumpAndSettle();

    expect(find.text('Kết nối hệ thống Pi'), findsOneWidget);
    expect(find.byKey(const Key('phone')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('fireeye-url')))
          .controller!
          .text,
      'http://100.95.189.60:8000',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('fireguard-url')))
          .controller!
          .text,
      'http://100.95.189.60:8080',
    );
  });
}
