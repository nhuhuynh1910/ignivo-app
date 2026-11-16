import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/models/push_notification_model.dart';
import 'package:ignivo_app/core/services/messaging_service.dart';
import 'package:ignivo_app/widgets/ignivo_floating_notification_banner.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IgnivoPushNotification Model Parsing Tests', () {
    test('Parses fire incident payload into fireEmergency with decorative title', () {
      final message = RemoteMessage(
        messageId: 'fire_msg_101',
        data: {
          'trigger_type': 'FIRE',
          'severity': 'critical',
          'incident_id': '45',
          'camera_name': 'Xưởng cơ khí #2',
          'image_url': 'https://example.com/snapshot.jpg',
        },
      );

      final notif = IgnivoPushNotification.fromRemoteMessage(message);

      expect(notif.id, 'fire_msg_101');
      expect(notif.category, PushNotificationCategory.fireEmergency);
      expect(notif.triggerType, 'FIRE');
      expect(notif.severity, 'critical');
      expect(notif.incidentId, 45);
      expect(notif.cameraName, 'Xưởng cơ khí #2');
      expect(notif.imageUrl, 'https://example.com/snapshot.jpg');
      expect(notif.title, contains('🔥 BÁO ĐỘNG CHÁY CẤP BÁCH (Xưởng cơ khí #2)'));
      expect(notif.body, contains('AI thị giác phát hiện ngọn lửa bốc lên'));
    });

    test('Parses trigger_type SMOKE with area and confidence', () {
      final message = RemoteMessage(
        messageId: 'smoke_msg_102',
        data: {
          'trigger_type': 'SMOKE',
          'risk_level': 'high',
          'id': '88',
          'area': 'Bếp tầng 1',
          'camera_name': 'Cam-01',
          'confidence': '0.94',
        },
      );

      final notif = IgnivoPushNotification.fromRemoteMessage(message);

      expect(notif.category, PushNotificationCategory.fireEmergency);
      expect(notif.triggerType, 'SMOKE');
      expect(notif.incidentId, 88);
      expect(notif.area, 'Bếp tầng 1');
      expect(notif.title, contains('💨 CẢNH BÁO PHÁT HIỆN KHÓI (Bếp tầng 1)'));
      expect(notif.body, contains('94%'));
    });

    test('Parses simulation incident correctly', () {
      final message = RemoteMessage(
        messageId: 'sim_msg_103',
        data: {
          'trigger_type': 'FIRE',
          'is_simulation': 'true',
          'area': 'Khu thử nghiệm',
        },
      );

      final notif = IgnivoPushNotification.fromRemoteMessage(message);

      expect(notif.isSimulation, isTrue);
      expect(notif.title, contains('🧪 [MÔ PHỎNG] BÁO ĐỘNG CHÁY (Khu thử nghiệm)'));
      expect(notif.body, contains('Không có nguy hiểm thực tế'));
    });

    test('Parses known face recognition into faceRecognition with 🟢 badge', () {
      final message = RemoteMessage(
        messageId: 'face_msg_202',
        data: {
          'type': 'known_person',
          'person_name': 'Nguyễn Văn A',
          'camera_name': 'Cổng chính Dahua',
          'is_known': 'true',
        },
      );

      final notif = IgnivoPushNotification.fromRemoteMessage(message);

      expect(notif.category, PushNotificationCategory.faceRecognition);
      expect(notif.isKnownPerson, isTrue);
      expect(notif.personName, 'Nguyễn Văn A');
      expect(notif.title, '🟢 Người quen: Nguyễn Văn A');
      expect(notif.body, contains('Đã xác nhận sự có mặt của Nguyễn Văn A'));
    });

    test('Parses unknown person detection into faceRecognition with 🚨 badge', () {
      final message = RemoteMessage(
        messageId: 'face_msg_303',
        data: {
          'type': 'unknown_person',
          'camera_name': 'Khuôn viên sau',
        },
      );

      final notif = IgnivoPushNotification.fromRemoteMessage(message);

      expect(notif.category, PushNotificationCategory.faceRecognition);
      expect(notif.isKnownPerson, isFalse);
      expect(notif.title, '🚨 Cảnh báo: Phát hiện người lạ!');
      expect(notif.body, contains('Phát hiện đối tượng chưa được đăng ký trong danh bạ'));
    });

    test('Parses system notice and adds ⚙️ prefix', () {
      final message = RemoteMessage(
        messageId: 'sys_msg_404',
        notification: const RemoteNotification(
          title: 'Edge Box Pi 5 mất kết nối',
          body: 'Đang tự động kết nối lại...',
        ),
        data: {
          'type': 'system_offline',
        },
      );

      final notif = IgnivoPushNotification.fromRemoteMessage(message);

      expect(notif.category, PushNotificationCategory.systemNotice);
      expect(notif.title, '⚙️ Edge Box Pi 5 mất kết nối');
      expect(notif.body, 'Đang tự động kết nối lại...');
    });
  });

  group('MessagingService Dispatch & Streams', () {
    test('dispatchPushEvent broadcasts to onPushReceived stream', () async {
      final service = MessagingService();
      final captured = <IgnivoPushNotification>[];

      final sub = service.onPushReceived.listen(captured.add);

      final testNotif = IgnivoPushNotification(
        id: 'test_push_1',
        category: PushNotificationCategory.fireEmergency,
        title: '🔥 Test Alert',
        body: 'Testing notification stream',
        timestamp: DateTime.now(),
      );

      service.dispatchPushEvent(testNotif, showSystemNotification: false);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(captured.length, 1);
      expect(captured.first.id, 'test_push_1');
      expect(captured.first.title, '🔥 Test Alert');

      await sub.cancel();
      service.dispose();
    });

    test('getInstallationId generates and persists in SharedPreferences', () async {
      final service = MessagingService();
      final id1 = await service.getInstallationId();
      final id2 = await service.getInstallationId();

      expect(id1, isNotEmpty);
      expect(id1, id2);
    });
  });

  group('IgnivoFloatingNotificationBanner Widget Tests', () {
    testWidgets('Renders emergency banner and responds to tap', (tester) async {
      bool tapped = false;
      final notif = IgnivoPushNotification(
        id: 'banner_test_1',
        category: PushNotificationCategory.fireEmergency,
        triggerType: 'FIRE',
        area: 'Phòng khách',
        cameraName: 'Camera #1',
        title: '🔥 Báo động cháy phòng khách',
        body: 'Khói nhiệt độ cao vượt ngưỡng an toàn',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IgnivoFloatingNotificationBanner(
              notification: notif,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('KHẨN CẤP'), findsOneWidget);
      expect(find.text('🔥 Báo động cháy phòng khách'), findsOneWidget);
      expect(find.text('Phòng khách • Camera #1'), findsOneWidget);
      expect(find.text('Khói nhiệt độ cao vượt ngưỡng an toàn'), findsOneWidget);
      expect(find.text('Xem'), findsOneWidget);

      await tester.tap(find.text('Xem'));
      expect(tapped, isTrue);
    });

    testWidgets('Renders face recognition banner for known person', (tester) async {
      final notif = IgnivoPushNotification(
        id: 'banner_test_2',
        category: PushNotificationCategory.faceRecognition,
        title: '🟢 Người quen: Trương Gia Bình',
        body: 'Đã nhận diện tại sảnh chính',
        isKnownPerson: true,
        personName: 'Trương Gia Bình',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IgnivoFloatingNotificationBanner(
              notification: notif,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NGƯỜI QUEN'), findsOneWidget);
      expect(find.text('🟢 Người quen: Trương Gia Bình'), findsOneWidget);
      expect(find.text('Đã nhận diện tại sảnh chính'), findsOneWidget);
    });

    test('Serializes toMap and deserializes fromMap preserving critical alert fields', () {
      final notif = IgnivoPushNotification(
        id: 'serialize_test_101',
        category: PushNotificationCategory.fireEmergency,
        title: '🔥 BÁO ĐỘNG CHÁY CẤP BÁCH',
        body: 'Phát hiện ngọn lửa tại Tầng 2',
        incidentId: 88,
        cameraId: 3,
        cameraName: 'Camera Bếp',
        area: 'Bếp tầng 2',
        triggerType: 'FIRE',
        severity: 'critical',
        confidence: 0.97,
        timestamp: DateTime(2026, 11, 5, 12, 0),
      );

      final map = notif.toMap();
      final revived = IgnivoPushNotification.fromMap(map);

      expect(revived.id, 'serialize_test_101');
      expect(revived.category, PushNotificationCategory.fireEmergency);
      expect(revived.title, '🔥 BÁO ĐỘNG CHÁY CẤP BÁCH');
      expect(revived.body, 'Phát hiện ngọn lửa tại Tầng 2');
      expect(revived.incidentId, 88);
      expect(revived.cameraId, 3);
      expect(revived.cameraName, 'Camera Bếp');
      expect(revived.area, 'Bếp tầng 2');
      expect(revived.triggerType, 'FIRE');
      expect(revived.severity, 'critical');
      expect(revived.confidence, 0.97);
    });
  });
}
