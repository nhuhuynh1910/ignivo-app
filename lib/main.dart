import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'core/services/local_notification_service.dart';
import 'core/services/messaging_service.dart';
import 'core/services/system_session_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/app_entry_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    try {
      await LocalNotificationService.instance.initialize();
    } catch (e) {
      debugPrint('LocalNotificationService pre-init error: $e');
    }
  } catch (e) {
    debugPrint('Firebase initialization skipped or failed: $e');
  }
  runApp(const IgnivoApp(showInitialSplash: true));
}

class IgnivoApp extends StatelessWidget {
  const IgnivoApp({
    super.key,
    this.sessionController,
    this.authenticatedBuilder,
    this.showInitialSplash = false,
  });

  final SystemSessionController? sessionController;
  final Widget Function(BuildContext context, SystemSessionController controller)?
      authenticatedBuilder;
  final bool showInitialSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGNIVO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AppEntryGate(
        sessionController: sessionController,
        authenticatedBuilder: authenticatedBuilder,
        showInitialSplash: showInitialSplash,
      ),
    );
  }
}
