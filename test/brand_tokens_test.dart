import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/core/theme/app_theme.dart';
import 'package:ignivo_app/core/theme/brand_tokens.dart';
import 'package:ignivo_app/widgets/ignivo_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gói B1: BrandTokens & StatusStyle Unit Tests', () {
    test('BrandTokens defines proper primary and contrast tokens', () {
      expect(BrandTokens.brandPrimary, const Color(0xFF005CAF));
      expect(BrandTokens.brandNavy, const Color(0xFF102449));
      expect(BrandTokens.brandCyan, const Color(0xFF16B9EE));
      expect(BrandTokens.darkBackground, const Color(0xFF091426));
      expect(BrandTokens.darkSurface, const Color(0xFF101E35));
      expect(BrandTokens.darkPrimary, const Color(0xFF63CBFF));
      expect(BrandTokens.darkOnPrimary, const Color(0xFF06152F));
    });

    test('AppColors backwards-compatible aliases point to BrandTokens', () {
      expect(AppColors.primary, BrandTokens.brandPrimary);
      expect(AppColors.primarySecondary, BrandTokens.brandNavy);
      expect(AppColors.darkBackground, BrandTokens.darkBackground);
      expect(AppColors.darkSurface, BrandTokens.darkSurface);
    });

    test('StatusStyle maps severities correctly in light mode', () {
      final crit = StatusStyle.forSeverity('critical', isDark: false);
      expect(crit.foreground, BrandTokens.criticalFg);
      expect(crit.background, BrandTokens.criticalBg);
      expect(crit.border, BrandTokens.criticalBorder);

      final high = StatusStyle.forSeverity('high', isDark: false);
      expect(high.foreground, BrandTokens.highFg);

      final med = StatusStyle.forSeverity('medium', isDark: false);
      expect(med.foreground, BrandTokens.mediumFg);

      final low = StatusStyle.forSeverity('low', isDark: false);
      expect(low.foreground, BrandTokens.lowFg);

      final none = StatusStyle.forSeverity('none', isDark: false);
      expect(none.foreground, BrandTokens.lowFg);

      final unk = StatusStyle.forSeverity(null, isDark: false);
      expect(unk.foreground, BrandTokens.staleFg);
    });

    test('StatusStyle maps severities correctly in dark mode', () {
      final crit = StatusStyle.forSeverity('critical', isDark: true);
      expect(crit.foreground, BrandTokens.darkCriticalFg);
      expect(crit.background, BrandTokens.darkCriticalBg);
      expect(crit.border, BrandTokens.darkCriticalBorder);

      final normal = StatusStyle.normal(isDark: true);
      expect(normal.foreground, BrandTokens.darkNormalFg);

      final stale = StatusStyle.stale(isDark: true);
      expect(stale.foreground, BrandTokens.darkStaleFg);
    });
  });

  group('Gói B1: IgnivoLogo Widget Tests', () {
    testWidgets('IgnivoLogo.wordmark renders with container and semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IgnivoLogo.wordmark(width: 200),
            ),
          ),
        ),
      );

      expect(find.byType(IgnivoLogo), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Verify semantics
      expect(find.bySemanticsLabel('IGNIVO'), findsOneWidget);
    });

    testWidgets('IgnivoLogo.mark renders correctly with custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IgnivoLogo.mark(size: 64),
            ),
          ),
        ),
      );

      expect(find.byType(IgnivoLogo), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.bySemanticsLabel('Logo IGNIVO'), findsOneWidget);
    });

    testWidgets('IgnivoLogo.header excludes semantics when requested', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IgnivoLogo.header(),
            ),
          ),
        ),
      );

      expect(find.byType(IgnivoLogo), findsOneWidget);
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('AppTheme light and dark themes build without throwing', (tester) async {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, BrandTokens.brandPrimary);
      expect(dark.colorScheme.primary, BrandTokens.darkPrimary);
      expect(dark.elevatedButtonTheme.style?.foregroundColor?.resolve({}), BrandTokens.darkOnPrimary);
    });
  });
}
