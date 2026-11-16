import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/push_notification_model.dart';
import 'fireguard_api_service.dart';
import 'local_notification_service.dart';

/// Top-level background message handler cho Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message received: ${message.messageId}');
  try {
    final pushModel = IgnivoPushNotification.fromRemoteMessage(message);
    final local = LocalNotificationService.instance;
    if (!local.isInitialized) {
      await local.initialize();
    }
    await local.showNotification(pushModel);
  } catch (e) {
    debugPrint('Error showing local notification in background handler: $e');
  }
}

/// Dịch vụ quản lý thông báo đẩy Firebase Cloud Messaging (FCM)
/// Tích hợp Clean Code: Tách biệt phân tích Model, Local Notification và In-App Dispatch
class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FireguardApiService? api,
    LocalNotificationService? localNotifications,
  })  : _messaging = messaging,
        _api = api ?? FireguardApiService.instance,
        _localNotifications = localNotifications ?? LocalNotificationService.instance;

  static MessagingService? _instance;
  static MessagingService get instance => _instance ??= MessagingService();

  final FirebaseMessaging? _messaging;
  FireguardApiService _api;
  final LocalNotificationService _localNotifications;
  final Set<FireguardApiService> _activeApis = {};

  static const _installationIdKey = 'ignivo_installation_id';

  final StreamController<IgnivoPushNotification> _pushController =
      StreamController<IgnivoPushNotification>.broadcast();
  Stream<IgnivoPushNotification> get onPushReceived => _pushController.stream;

  final StreamController<IgnivoPushNotification> _openedController =
      StreamController<IgnivoPushNotification>.broadcast();
  Stream<IgnivoPushNotification> get onNotificationOpened => _openedController.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  FirebaseMessaging? get _resolvedMessaging {
    try {
      return _messaging ?? FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  Future<String> getInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installationIdKey);
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      id = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_installationIdKey, id);
    }
    return id;
  }

  /// Khởi tạo toàn bộ dịch vụ FCM và hệ thống thông báo đẩy
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Khởi tạo Local Notification OS Service
    try {
      await _localNotifications.initialize(
        onNotificationClick: (payload) {
          if (payload != null && payload.isNotEmpty) {
            try {
              final map = jsonDecode(payload) as Map<String, dynamic>;
              final push = IgnivoPushNotification.fromMap(map);
              _openedController.add(push);
            } catch (e) {
              debugPrint('Lỗi giải mã payload khi nhấn notification: $e');
            }
          }
        },
      );
    } catch (e) {
      debugPrint('LocalNotificationService initialize error: $e');
    }

    final messaging = _resolvedMessaging;
    if (messaging == null) {
      _initialized = true;
      return;
    }

    try {
      // 2. Yêu cầu quyền nhận thông báo
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 3. Đăng ký nhận token
        final token = await messaging.getToken();
        if (token != null) {
          for (final a in _activeApis) {
            await registerWithApi(a, token: token);
          }
          if (_api.authToken != null) {
            await registerDevice(token);
          }
        }

        messaging.onTokenRefresh.listen((newToken) async {
          for (final a in _activeApis) {
            await registerWithApi(a, token: newToken);
          }
          if (_api.authToken != null) {
            await registerDevice(newToken);
          }
        });

        // Tự động đồng bộ lại token lên Pi khi phiên đăng nhập thay đổi hoặc kết nối lại
        _api.sessionChanges.listen((_) async {
          if (_api.authToken != null) {
            try {
              final currentToken = await messaging.getToken();
              if (currentToken != null) {
                await registerDevice(currentToken);
              }
            } catch (e) {
              debugPrint('Error resyncing FCM token on session change: $e');
            }
          }
        });
      }

      // 4. Lắng nghe thông báo khi ứng dụng đang mở (Foreground Push)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final pushModel = IgnivoPushNotification.fromRemoteMessage(message);

        // Hiển thị heads-up notification của hệ điều hành
        _localNotifications.showNotification(pushModel);

        // Phát ra stream để giao diện hiển thị In-App Floating Toast
        _pushController.add(pushModel);
      });

      // 5. Xử lý khi người dùng nhấn vào thông báo mở app từ nền (Background tap)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final pushModel = IgnivoPushNotification.fromRemoteMessage(message);
        _openedController.add(pushModel);
      });

      // 6. Xử lý khi app được mở từ trạng thái Terminated do người dùng nhấn thông báo
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final pushModel = IgnivoPushNotification.fromRemoteMessage(initialMessage);
        _openedController.add(pushModel);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('FirebaseMessaging initialize error: $e');
    }
  }

  /// Cho phép phát sự kiện Push thủ công (dành cho kiểm thử hoặc WebSockets)
  void dispatchPushEvent(IgnivoPushNotification notification, {bool showSystemNotification = true}) {
    if (showSystemNotification) {
      _localNotifications.showNotification(notification);
    }
    _pushController.add(notification);
  }

  /// Thiết lập API FireGuard đang hoạt động và đăng ký token nếu có thể
  void setActiveApi(FireguardApiService api) {
    _api = api;
    _activeApis.add(api);
    if (api.authToken != null && api.authToken!.isNotEmpty) {
      unawaited(getDeviceToken().then((token) {
        if (token != null && token.isNotEmpty) {
          registerWithApi(api, token: token);
        }
      }));
    }
  }

  /// Lấy mã định danh FCM registration token của thiết bị
  Future<String?> getDeviceToken() async {
    final messaging = _resolvedMessaging;
    if (messaging == null) return null;
    try {
      return await messaging.getToken();
    } catch (e) {
      debugPrint('[MessagingService] Lỗi lấy FCM token: $e');
      return null;
    }
  }

  /// Đăng ký thiết bị nhận thông báo đẩy tới một Pi cụ thể
  Future<bool> registerWithApi(
    FireguardApiService targetApi, {
    String? token,
    String? deviceName,
  }) async {
    _activeApis.add(targetApi);
    if (targetApi.authToken == null || targetApi.authToken!.isEmpty) {
      debugPrint('[MessagingService] Bỏ qua đăng ký: Token của Pi rỗng (${targetApi.baseUrl})');
      return false;
    }

    final fcmToken = token ?? await getDeviceToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('[MessagingService] FCM token chưa sẵn sàng.');
      return false;
    }

    final installId = await getInstallationId();
    final platform = Platform.isIOS ? 'ios' : 'android';
    final ok = await targetApi.registerNotificationDevice(
      installationId: installId,
      token: fcmToken,
      platform: platform,
      deviceName: deviceName ?? 'IGNIVO Mobile App',
    );
    debugPrint('[MessagingService] Đăng ký thiết bị với Pi (${targetApi.baseUrl}): ok=$ok (id: $installId)');
    return ok;
  }

  /// Hủy đăng ký nhận thông báo đẩy từ một Pi cụ thể
  Future<bool> unregisterWithApi(
    FireguardApiService targetApi, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _activeApis.remove(targetApi);
    try {
      final installId = await getInstallationId();
      return await targetApi
          .unregisterNotificationDevice(installId)
          .timeout(timeout);
    } catch (e) {
      debugPrint('[MessagingService] Lỗi hủy đăng ký thiết bị: $e');
      return false;
    }
  }

  Future<bool> registerDevice(String token) async {
    if (_api.authToken == null) return false;
    final installId = await getInstallationId();
    final platform = Platform.isIOS ? 'ios' : 'android';
    return _api.registerNotificationDevice(
      installationId: installId,
      token: token,
      platform: platform,
    );
  }

  Future<bool> unregisterDevice({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = prefs.getString(_installationIdKey);
      if (installId == null || installId.isEmpty) return true;
      return await _api
          .unregisterNotificationDevice(installId)
          .timeout(timeout);
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _pushController.close();
    _openedController.close();
  }
}
