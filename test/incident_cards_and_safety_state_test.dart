import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/fireguard/fireguard_page.dart';
import 'package:ignivo_app/features/fireguard/monitor_widgets.dart';
import 'package:ignivo_app/widgets/ignivo_shimmer.dart';
import 'package:ignivo_app/widgets/recent_incident_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fireguard_page_test.dart' show TestRealtime;

http.Response _jsonResp(Object? data, [int code = 200]) => http.Response(
      jsonEncode(data),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Đề xuất 2: IncidentPresentationHelper Unit Tests', () {
    test('formatIncidentTitle formats "[Loại sự cố] · [Camera] · [Khu vực]" cleanly', () {
      final incident = {
        'id': 1,
        'trigger_type': 'fire',
        'camera_name': 'Camera phòng khách',
        'area': 'Tầng 1',
      };
      expect(
        IncidentPresentationHelper.formatIncidentTitle(incident),
        'Phát hiện Lửa · Camera phòng khách · Tầng 1',
      );
    });

    test('formatIncidentTitle avoids repeating area when cameraName contains it', () {
      final incident = {
        'id': 2,
        'trigger_type': 'smoke',
        'camera_name': 'Camera Bếp Ăn',
        'area': 'Bếp Ăn',
      };
      expect(
        IncidentPresentationHelper.formatIncidentTitle(incident),
        'Phát hiện Khói · Camera Bếp Ăn',
      );
    });

    test('formatIncidentTitle handles simulation and fallback camera ID', () {
      final incident = {
        'id': 99,
        'trigger_type': 'simulation',
        'camera_id': 3,
      };
      expect(
        IncidentPresentationHelper.formatIncidentTitle(incident),
        'Sự cố mô phỏng · Camera #3',
      );
    });

    test('formatTimestamp returns human-friendly relative time', () {
      final now = DateTime.now();
      expect(
        IncidentPresentationHelper.formatTimestamp(now.toIso8601String()),
        'Vừa xong',
      );

      final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
      expect(
        IncidentPresentationHelper.formatTimestamp(tenMinutesAgo.toIso8601String()),
        '10 phút trước',
      );

      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(
        IncidentPresentationHelper.formatTimestamp(twoHoursAgo.toIso8601String()),
        '2 giờ trước',
      );

      expect(IncidentPresentationHelper.formatTimestamp(null), '');
      expect(IncidentPresentationHelper.formatTimestamp(''), '');
    });
  });

  group('Đề xuất 2: RecentIncidentTile Widget Tests', () {
    testWidgets('renders title cleanly and moves #id badge to subtitle row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentIncidentTile(
              id: 42,
              title: 'Phát hiện Lửa · Camera phòng khách · Tầng 1',
              area: 'Tầng 1',
              timeStr: '5 phút trước',
              severity: 'critical',
              status: 'notifying',
            ),
          ),
        ),
      );

      // Main title does NOT have forced (#42) attached to it
      expect(find.text('Phát hiện Lửa · Camera phòng khách · Tầng 1'), findsOneWidget);
      expect(find.text('Phát hiện Lửa · Camera phòng khách · Tầng 1 (#42)'), findsNothing);

      // #42 is placed as a secondary badge in the metadata area
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Tầng 1'), findsOneWidget);
      expect(find.text('5 phút trước'), findsOneWidget);
    });

    testWidgets('renders thumbnail image and trigger overlay badge when imageBytes provided', (tester) async {
      final fakeBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentIncidentTile(
              id: 55,
              title: 'Cảnh báo Khói · Bếp',
              area: 'Bếp',
              timeStr: 'Vừa xong',
              severity: 'warning',
              status: 'active',
              imageBytes: fakeBytes,
              triggerType: 'smoke',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    });

    testWidgets('renders shimmer loading when isImageLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentIncidentTile(
              id: 56,
              title: 'Cảnh báo Lửa · Kho',
              area: 'Kho',
              timeStr: '1 phút trước',
              severity: 'critical',
              status: 'notifying',
              isImageLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(IgnivoShimmerBox), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders fallback icon with trigger type when no image and not loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentIncidentTile(
              id: 57,
              title: 'Cảnh báo Camera · Cổng',
              area: 'Cổng',
              timeStr: '2 phút trước',
              severity: 'info',
              status: 'resolved',
              triggerType: 'camera',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(IgnivoShimmerBox), findsNothing);
    });
  });

  group('Đề xuất 3: FireguardPage Empty State vs Safe State Tests', () {
    testWidgets('displays "Không có sự cố trong bộ lọc này" without green verified "Hệ thống an toàn"', (
      tester,
    ) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) return http.Response(jsonEncode({'role': 'OWNER'}), 200);
          if (r.url.path.endsWith('/system/info')) return http.Response(jsonEncode({'hostname': 'Pi5'}), 200);
          if (r.url.path.endsWith('/status')) {
            return http.Response(jsonEncode({'vision': {'ready': true}}), 200);
          }
          if (r.url.path.endsWith('/cameras')) return http.Response(jsonEncode([]), 200);
          if (r.url.path.endsWith('/incidents/active')) return http.Response(jsonEncode(null), 200);
          if (r.url.path.endsWith('/incidents')) return http.Response(jsonEncode([]), 200);
          return http.Response(jsonEncode({}), 200);
        }),
      );
      await api.setBaseUrl('http://pi:8080');
      await api.setAuthToken('test');
      final realtime = TestRealtime(api);

      await tester.pumpWidget(
        MaterialApp(
          home: FireguardPage(api: api, realtime: realtime),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Incidents tab (tab index 1)
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();

      // MUST NOT say "Hệ thống an toàn" or display green verified shield icon
      expect(find.text('Hệ thống an toàn'), findsNothing);
      expect(find.byIcon(Icons.verified_user_outlined), findsNothing);

      // MUST display clear empty filter messaging
      expect(find.text('Không có sự cố trong bộ lọc này'), findsOneWidget);
      expect(find.text('Không có sự cố trong nhóm này.'), findsOneWidget);
      expect(find.textContaining('Cập nhật lần cuối:'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_off_rounded), findsOneWidget);
    });

    testWidgets('incident card leads with descriptive title and secondary #id badge in FireguardPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final incident = {
        'id': 15,
        'trigger_type': 'fire',
        'status': 'open',
        'severity': 'critical',
        'camera_name': 'Camera Hành Lang',
        'area': 'Tầng 2',
        'created_at': DateTime.now().toIso8601String(),
      };

      final api = FireguardApiService(
        client: MockClient((r) async {
          final suffix = r.url.path.replaceFirst('/api/v1/emergency', '');
          Object? value;
          switch (suffix) {
            case '/auth/me':
              value = {'role': 'OWNER'};
            case '/system/info':
              value = {'hostname': 'Pi5'};
            case '/status':
              value = {
                'detection_source': 'local',
                'vision': {'ready': true},
              };
            case '/cameras':
              value = <Map<String, dynamic>>[];
            case '/incidents':
              value = [incident];
            case '/incidents/active':
              value = incident;
            case '/incidents/15':
              value = incident;
            default:
              value = {'status': 'ok'};
          }
          return _jsonResp(value);
        }),
      );
      await api.setBaseUrl('http://pi:8080');
      await api.setAuthToken('test');
      final realtime = TestRealtime(api);

      await tester.pumpWidget(
        MaterialApp(
          home: FireguardPage(api: api, realtime: realtime),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Incidents tab
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();

      // Title should lead with "Phát hiện Lửa · Camera Hành Lang · Tầng 2"
      expect(find.text('Phát hiện Lửa · Camera Hành Lang · Tầng 2'), findsOneWidget);
      // It should NOT lead with raw technical pattern "#15 · Camera Hành Lang · fire"
      expect(find.textContaining('#15 · Camera Hành Lang · fire'), findsNothing);
      // Secondary #15 badge should exist in the card
      expect(find.text('#15'), findsOneWidget);
    });
  });
}
