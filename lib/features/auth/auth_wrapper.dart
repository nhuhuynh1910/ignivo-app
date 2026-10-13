import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../navigation/main_navigation.dart';
import 'complete_profile_page.dart';
import 'login_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return _ProfileGate(user: user);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
    required this.user,
  });

  final User user;

  @override
  State<_ProfileGate> createState() =>
      _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  final FirestoreService _firestoreService =
  FirestoreService();

  @override
  void initState() {
    super.initState();

    _prepareProfile();
  }

  Future<void> _prepareProfile() async {
    final isGoogle = widget.user.providerData.any(
          (provider) =>
      provider.providerId == 'google.com',
    );

    if (isGoogle) {
      await _firestoreService.ensureGoogleUserDocument(
        widget.user,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.watchUserProfile(
        widget.user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting ||
            !snapshot.hasData) {
          return const _LoadingScreen();
        }

        final document = snapshot.data;

        if (document == null || !document.exists) {
          return CompleteProfilePage(
            user: widget.user,
          );
        }

        final data = document.data() ?? {};

        final name =
        (data['name'] ?? '').toString().trim();

        final phone =
        (data['phone'] ?? '').toString().trim();

        final profileComplete =
            data['profileComplete'] == true;

        if (!profileComplete ||
            name.isEmpty ||
            phone.isEmpty) {
          return CompleteProfilePage(
            user: widget.user,
          );
        }

        return const MainNavigation();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}