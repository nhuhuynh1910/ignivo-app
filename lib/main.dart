import 'package:flutter/material.dart';

import 'core/services/system_session_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/app_entry_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
