import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/edge_connection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IgnivoApp());
}

class IgnivoApp extends StatelessWidget {
  const IgnivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGNIVO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const EdgeConnectionPage(),
    );
  }
}
