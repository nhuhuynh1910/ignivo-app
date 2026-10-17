import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/core/theme/app_theme.dart';
import 'package:ignivo_app/features/settings/brand_showcase_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildShowcaseHarness({
    required Size surfaceSize,
    required double textScale,
    required bool isDark,
  }) {
    return MaterialApp(
      theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: SizedBox(
          width: surfaceSize.width,
          height: surfaceSize.height,
          child: const BrandShowcasePage(),
        ),
      ),
    );
  }

  group('Gói B2: BrandShowcasePage Widget & Responsive Tests', () {
    testWidgets('Renders Component Gallery at 360px width and 200% text scale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildShowcaseHarness(
          surfaceSize: const Size(360, 800),
          textScale: 2.0,
          isDark: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IGNIVO Brand Showcase'), findsOneWidget);
      expect(find.text('1. Logo IGNIVO chuẩn hóa (Badge Card Container)'), findsOneWidget);
      expect(find.text('CRITICAL (Khẩn cấp)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Switches to Dark Theme without throwing', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildShowcaseHarness(
          surfaceSize: const Size(360, 800),
          textScale: 1.0,
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      // Find dark mode switch in AppBar actions and tap it
      final toggleThemeBtn = find.byTooltip('Chuyển sang nền tối');
      expect(toggleThemeBtn, findsOneWidget);
      await tester.tap(toggleThemeBtn);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Chuyển sang nền sáng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Mock Login tab at 360px and 200% text scale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildShowcaseHarness(
          surfaceSize: const Size(360, 800),
          textScale: 2.0,
          isDark: false,
        ),
      );
      await tester.pumpAndSettle();

      // Swipe to Login tab
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống Giám sát & Báo cháy IGNIVO'), findsOneWidget);
      expect(find.text('Đăng nhập vận hành'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Mock Home tab and toggles Urgent state', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildShowcaseHarness(
          surfaceSize: const Size(360, 800),
          textScale: 1.0,
          isDark: false,
        ),
      );
      await tester.pumpAndSettle();

      // Swipe twice to Home tab
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();

      expect(find.text('Tòa nhà IGNIVO - Khu A'), findsOneWidget);
      expect(find.text('Trạng thái: Bình thường an toàn'), findsOneWidget);

      // Toggle switch to Urgent
      final urgentSwitch = find.byType(Switch);
      expect(urgentSwitch, findsOneWidget);
      await tester.tap(urgentSwitch);
      await tester.pumpAndSettle();

      expect(find.text('Trạng thái: Có sự cố khẩn cấp'), findsOneWidget);
      expect(find.text('SỰ CỐ CẦN CHÚ Ý'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Mock Incident Detail and performs local ACK/Silence toggle', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildShowcaseHarness(
          surfaceSize: const Size(360, 800),
          textScale: 1.0,
          isDark: false,
        ),
      );
      await tester.pumpAndSettle();

      // Swipe 3 times to Incident Detail tab
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();

      // Drag up to expose action buttons at bottom of list
      await tester.drag(find.text('Phát hiện ngọn lửa bùng phát'), const Offset(0, -350));
      await tester.pumpAndSettle();

      final ackBtn = find.text('Xác nhận đã biết sự cố (ACK)');
      expect(ackBtn, findsOneWidget);

      // Tap ACK button
      await tester.tap(ackBtn);
      await tester.pumpAndSettle();

      expect(find.text('Đã xác nhận sự cố (Bấm để hủy ACK mẫu)'), findsOneWidget);

      // Tap Silence button
      final silenceBtn = find.text('Tắt âm còi cục bộ');
      expect(silenceBtn, findsOneWidget);
      await tester.tap(silenceBtn);
      await tester.pumpAndSettle();

      expect(find.text('Bật lại âm thanh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
