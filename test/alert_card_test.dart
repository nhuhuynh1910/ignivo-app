import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/models/alert_model.dart';
import 'package:ignivo_app/widgets/alert_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlertCard Evidence Thumbnail & Fallback Tests', () {
    testWidgets('renders evidence thumbnail image when snapshotUrl is present', (tester) async {
      bool tapped = false;
      const alertWithSnapshot = AlertModel(
        id: 'alert_101',
        systemId: 'sys_01',
        cameraId: 'cam_01',
        cameraName: 'Camera Kho Hàng',
        type: 'FIRE',
        severity: 'CRITICAL',
        title: 'Cảnh báo cháy tại Kho Hàng',
        message: 'Phát hiện ngọn lửa bùng phát lớn',
        snapshotUrl: 'https://cdn.ignivo.vn/snapshots/fire_evidence_101.jpg',
        eventId: 'evt_101',
        incidentSummary: 'Phát hiện lửa',
        acknowledged: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertCard(
              alert: alertWithSnapshot,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      // Verify Title & Info
      expect(find.text('Cảnh báo cháy tại Kho Hàng'), findsOneWidget);
      expect(find.text('Camera Kho Hàng'), findsWidgets);
      expect(find.text('NGUY HIỂM'), findsOneWidget);

      // Verify Image is present for evidence snapshot
      expect(find.byType(Image), findsOneWidget);

      // Verify category icon badge is rendered at the corner
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);

      // Verify onTap callback
      await tester.tap(find.byType(AlertCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders fallback icon when snapshotUrl is empty', (tester) async {
      const alertWithoutSnapshot = AlertModel(
        id: 'alert_102',
        systemId: 'sys_01',
        cameraId: 'cam_02',
        cameraName: 'Camera Hành Lang',
        type: 'SMOKE',
        severity: 'ALERT',
        title: 'Cảnh báo khói tại Hành Lang',
        message: 'Mật độ khói vượt ngưỡng',
        snapshotUrl: '',
        eventId: 'evt_102',
        incidentSummary: 'Phát hiện khói',
        acknowledged: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertCard(
              alert: alertWithoutSnapshot,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify Title & Severity
      expect(find.text('Cảnh báo khói tại Hành Lang'), findsOneWidget);
      expect(find.text('CẢNH BÁO'), findsOneWidget);

      // No network Image should be rendered when snapshotUrl is empty
      expect(find.byType(Image), findsNothing);

      // Fallback icon for SMOKE is rendered
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    });

    testWidgets('renders fallback icon when snapshotUrl is whitespace only', (tester) async {
      const alertWithWhitespaceSnapshot = AlertModel(
        id: 'alert_103',
        systemId: 'sys_01',
        cameraId: 'cam_03',
        cameraName: 'Cổng chính',
        type: 'INTRUSION',
        severity: 'SUSPICIOUS',
        title: 'Phát hiện xâm nhập',
        message: 'Người lạ tại cổng',
        snapshotUrl: '   ',
        eventId: 'evt_103',
        incidentSummary: 'Phát hiện người lạ',
        acknowledged: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertCard(
              alert: alertWithWhitespaceSnapshot,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('BẤT THƯỜNG'), findsOneWidget);
    });
  });
}
