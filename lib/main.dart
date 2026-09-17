import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'navigation/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android hiện tại dùng Firebase native config.
  // Không initialize Firebase lại trên Android.
  if (!Platform.isAndroid) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const IgnivoApp());
}

class IgnivoApp extends StatelessWidget {
  const IgnivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGNIVO',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Montserrat',

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFAB0808),
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),

      home: const MainNavigation(),
    );
  }
}