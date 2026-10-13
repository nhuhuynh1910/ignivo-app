import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';

class PersonalInfoPage extends StatelessWidget {
  PersonalInfoPage({
    super.key,
  });

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService =
  FirestoreService();

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Không tìm thấy tài khoản.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream:
        _firestoreService.watchUserProfile(uid),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Không thể tải thông tin cá nhân.',
              ),
            );
          }

          final document = snapshot.data;

          if (document == null ||
              !document.exists) {
            return const Center(
              child: Text(
                'Không tìm thấy hồ sơ người dùng.',
              ),
            );
          }

          final data =
              document.data() ?? {};

          final name =
              data['name']?.toString().trim() ?? '';

          final email =
              data['email']?.toString().trim() ?? '';

          final phone =
              data['phone']?.toString().trim() ?? '';

          final photoUrl =
              data['photoUrl']?.toString().trim() ?? '';

          final authProvider =
              data['authProvider']
                  ?.toString()
                  .trim() ??
                  '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ============================================================
              // PROFILE HEADER
              // ============================================================

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(22),
                  border: Border.all(
                    color:
                    AppColors.backgroundBlueSoft,
                  ),
                ),
                child: Column(
                  children: [
                    _ProfileAvatar(
                      name: name,
                      photoUrl: photoUrl,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      name.isNotEmpty
                          ? name
                          : 'Người dùng IGNIVO',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      email.isNotEmpty
                          ? email
                          : 'Chưa có email',
                      style: const TextStyle(
                        fontSize: 13,
                        color:
                        AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ============================================================
              // PERSONAL INFORMATION
              // ============================================================

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(20),
                  border: Border.all(
                    color:
                    AppColors.backgroundBlueSoft,
                  ),
                ),
                child: Column(
                  children: [
                    _InfoTile(
                      icon:
                      Icons.person_outline_rounded,
                      title: 'Họ và tên',
                      value: name.isNotEmpty
                          ? name
                          : 'Chưa cập nhật',
                    ),

                    const _SettingsDivider(),

                    _InfoTile(
                      icon:
                      Icons.email_outlined,
                      title: 'Email',
                      value: email.isNotEmpty
                          ? email
                          : 'Chưa cập nhật',
                    ),

                    const _SettingsDivider(),

                    _InfoTile(
                      icon:
                      Icons.phone_outlined,
                      title: 'Số điện thoại',
                      value: phone.isNotEmpty
                          ? phone
                          : 'Chưa cập nhật',
                    ),

                    const _SettingsDivider(),

                    _InfoTile(
                      icon:
                      Icons.login_rounded,
                      title:
                      'Phương thức đăng nhập',
                      value: _providerLabel(
                        authProvider,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ============================================================
              // NOTE
              // ============================================================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                  AppColors.backgroundBlueSoft,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .verified_user_outlined,
                      color:
                      AppColors.primary,
                      size: 20,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Thông tin này được sử dụng để quản lý tài khoản IGNIVO và các hệ thống được liên kết với tài khoản của bạn.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors
                              .textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _providerLabel(
      String provider,
      ) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'Google';

      case 'password':
        return 'Email và mật khẩu';

      default:
        return provider.isEmpty
            ? 'Không xác định'
            : provider;
    }
  }
}

// ============================================================================
// PROFILE AVATAR
// ============================================================================

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.photoUrl,
  });

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundColor:
        AppColors.backgroundBlueSoft,
        backgroundImage:
        NetworkImage(photoUrl),
      );
    }

    final firstLetter =
    name.trim().isNotEmpty
        ? name
        .trim()
        .substring(0, 1)
        .toUpperCase()
        : 'I';

    return CircleAvatar(
      radius: 42,
      backgroundColor:
      AppColors.backgroundBlueSoft,
      child: Text(
        firstLetter,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

// ============================================================================
// INFORMATION TILE
// ============================================================================

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
              AppColors.backgroundBlueSoft,
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                    AppColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 70,
      color: AppColors.backgroundBlueSoft,
    );
  }
}