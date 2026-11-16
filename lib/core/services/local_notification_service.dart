import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/push_notification_model.dart';
import '../theme/brand_tokens.dart';

/// Dịch vụ quản lý thông báo cục bộ của hệ điều hành (Android / iOS)
/// Đảm bảo hiển thị Heads-up notification đẹp mắt, phân loại kênh (Channels) chuẩn
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void Function(String? payload)? onNotificationClick;

  // ==========================================
  // CÁC KÊNH THÔNG BÁO ANDROID (CHANNELS)
  // ==========================================
  static const String channelFireEmergencyId = 'ignivo_fire_emergency';
  static const String channelFaceSecurityId = 'ignivo_face_security';
  static const String channelSystemNoticeId = 'ignivo_system_notice';

  /// Khởi tạo plugin thông báo cục bộ
  Future<void> initialize({
    void Function(String? payload)? onNotificationClick,
  }) async {
    if (_isInitialized) return;
    this.onNotificationClick = onNotificationClick;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        this.onNotificationClick?.call(details.payload);
      },
    );

    await _createNotificationChannels();
    _isInitialized = true;
  }

  /// Tạo các kênh thông báo với mức độ ưu tiên và rung tương ứng trên Android 8.0+
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // 1. Kênh Cảnh báo Cháy Khẩn Cấp (Tối đa, có rung và đèn đỏ)
    final fireChannel = AndroidNotificationChannel(
      channelFireEmergencyId,
      'Cảnh báo Cháy Khẩn cấp',
      description: 'Thông báo nguy cơ cháy nổ, khói hoặc nhiệt độ cao từ hệ thống IGNIVO',
      importance: Importance.max,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 1000]),
      ledColor: BrandTokens.criticalFg,
      enableLights: true,
      playSound: true,
    );

    // 2. Kênh Nhận diện Khuôn mặt & An ninh
    final faceChannel = AndroidNotificationChannel(
      channelFaceSecurityId,
      'Nhận diện Khuôn mặt & An ninh',
      description: 'Thông báo xác nhận người quen hoặc cảnh báo người lạ xuất hiện',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      ledColor: BrandTokens.brandPrimary,
      enableLights: true,
    );

    // 3. Kênh Thông báo Hệ thống chung
    final systemChannel = AndroidNotificationChannel(
      channelSystemNoticeId,
      'Thông báo Hệ thống IGNIVO',
      description: 'Cập nhật tình trạng Edge Box, thiết bị và các sự kiện chung',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
    );

    await androidPlugin.createNotificationChannel(fireChannel);
    await androidPlugin.createNotificationChannel(faceChannel);
    await androidPlugin.createNotificationChannel(systemChannel);
  }

  /// Hiển thị thông báo đẹp mắt ra thanh thông báo OS
  Future<void> showNotification(IgnivoPushNotification notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    final int notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final details = _buildNotificationDetails(notification);

    await _localPlugin.show(
      id: notificationId,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(notification.toMap()),
    );
  }

  NotificationDetails _buildNotificationDetails(IgnivoPushNotification notification) {
    final String channelId;
    final String channelName;
    final String channelDesc;
    final Importance importance;
    final Priority priority;
    final Color color;

    switch (notification.category) {
      case PushNotificationCategory.fireEmergency:
        channelId = channelFireEmergencyId;
        channelName = 'Cảnh báo Cháy Khẩn cấp';
        channelDesc = 'Thông báo nguy cơ cháy nổ từ IGNIVO';
        importance = Importance.max;
        priority = Priority.max;
        color = BrandTokens.stitchCritical;
        break;

      case PushNotificationCategory.faceRecognition:
        channelId = channelFaceSecurityId;
        channelName = 'Nhận diện Khuôn mặt & An ninh';
        channelDesc = 'Thông báo sự kiện người quen / người lạ';
        importance = Importance.high;
        priority = Priority.high;
        color = (notification.isKnownPerson ?? false)
            ? BrandTokens.stitchSafe
            : BrandTokens.criticalFg;
        break;

      case PushNotificationCategory.systemNotice:
      case PushNotificationCategory.general:
        channelId = channelSystemNoticeId;
        channelName = 'Thông báo Hệ thống';
        channelDesc = 'Thông tin chung từ hệ thống an ninh';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        color = BrandTokens.brandPrimary;
        break;
    }

    final isFire = notification.category == PushNotificationCategory.fireEmergency;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      color: color,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: isFire,
      audioAttributesUsage: isFire ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      actions: isFire
          ? const [
              AndroidNotificationAction(
                'view_incident',
                '🚨 XEM CAMERA',
                showsUserInterface: true,
              ),
            ]
          : null,
      styleInformation: BigTextStyleInformation(
        notification.body,
        contentTitle: notification.title,
        summaryText: isFire ? '🔥 CẢNH BÁO CHÁY' : 'IGNIVO Safety',
        htmlFormatContent: false,
        htmlFormatContentTitle: false,
      ),
      category: isFire ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.status,
      ticker: notification.title,
      visibility: NotificationVisibility.public,
      onlyAlertOnce: false,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }
}
