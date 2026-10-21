import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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
  } catch (e) {
    debugPrint('Firebase initialization skipped or failed: $e');
  }
  runApp(const IgnivoApp());
}

class IgnivoApp extends StatelessWidget {
  const IgnivoApp({
    super.key,
    this.sessionController,
    this.authenticatedBuilder,
  });

  final SystemSessionController? sessionController;
  final Widget Function(BuildContext context, SystemSessionController controller)?
      authenticatedBuilder;

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
      ),
    );
  }
}
