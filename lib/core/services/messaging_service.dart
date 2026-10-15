import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fireguard_api_service.dart';

class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FireguardApiService? api,
  })  : _messaging = messaging,
        _api = api ?? FireguardApiService.instance;

  final FirebaseMessaging? _messaging;
  final FireguardApiService _api;
  static const _installationIdKey = 'ignivo_installation_id';

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
      id = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_installationIdKey, id);
    }
    return id;
  }

  Future<void> initialize() async {
    final messaging = _resolvedMessaging;
    if (messaging == null) return;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null) {
          await registerDevice(token);
        }

        messaging.onTokenRefresh.listen((token) async {
          await registerDevice(token);
        });
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Foreground pushes: coordinated with IncidentAlertCoordinator
      });
    } catch (_) {
      // Platform without Firebase configured
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

  Future<bool> unregisterDevice() async {
    final installId = await getInstallationId();
    return _api.unregisterNotificationDevice(installId);
  }
}
