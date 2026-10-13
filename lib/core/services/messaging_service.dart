import 'package:firebase_messaging/firebase_messaging.dart';

class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null) {
        _saveFcmToken(token);
      }

      _messaging.onTokenRefresh.listen(_saveFcmToken);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground alert push
    });
  }

  void _saveFcmToken(String token) {
    // Save token to current user document in Firestore
  }
}
