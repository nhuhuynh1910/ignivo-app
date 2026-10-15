import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../system/system_detail_page.dart';
import 'edge_connection_page.dart';
import 'emergency_contacts_page.dart';
import 'emergency_location_page.dart';
import 'personal_info_page.dart';
import 'security_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService =
    FirestoreService();

    final uid =
        authService.currentUserId;

    return Scaffold(
      backgroundColor:
      AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: uid == null
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: firestoreService
            .watchUserProfile(uid),
        builder: (
            context,
            snapshot,
            ) {
          final data =
              snapshot.data?.data() ??
                  {};

          final name =
              data['name']
                  ?.toString()
                  .trim() ??
                  '';

          final email =
              data['email']
                  ?.toString()
                  .trim() ??
                  '';

          final photoUrl =
              data['photoUrl']
                  ?.toString()
                  .trim() ??
                  '';

          return ListView(
            padding:
            const EdgeInsets.all(
              16,
            ),
            children: [
              // ===============================================
              // ACCOUNT CARD
              // ===============================================

              _AccountCard(
                name: name,
                email: email,
                photoUrl: photoUrl,
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PersonalInfoPage(),
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 22,
              ),

              // ===============================================
              // ACCOUNT
              // ===============================================

              const _SectionTitle(
                title: 'Tài khoản',
              ),

              const SizedBox(
                height: 8,
              ),

              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons
                        .person_outline_rounded,
                    title:
                    'Thông tin cá nhân',
                    subtitle:
                    'Tên, email và số điện thoại',
                    onTap: () {
                      Navigator.of(
                        context,
                      ).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PersonalInfoPage(),
                        ),
                      );
                    },
                  ),

                  const _SettingsDivider(),

                  _SettingsTile(
                    icon: Icons.security_outlined,
                    title: 'Bảo mật',
                    subtitle: 'Mật khẩu và đăng nhập',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SecurityPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // ===============================================
              // IGNIVO
              // ===============================================

              const _SectionTitle(
                title: 'IGNIVO',
              ),

              const SizedBox(
                height: 8,
              ),

              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.memory_rounded,
                    title: 'Quản lý thiết bị Edge Box',
                    subtitle: 'Trạng thái Raspberry Pi 5 & Hailo-8L',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SystemDetailPage()),
                      );
                    },
                  ),

                  const _SettingsDivider(),

                  _SettingsTile(
                    icon: Icons.lan_rounded,
                    title: 'Kết nối hệ thống Pi',
                    subtitle: 'FireEye, FireGuard và kết nối Tailscale',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EdgeConnectionPage()),
                      );
                    },
                  ),

                  const _SettingsDivider(),

                  _SettingsTile(
                    icon: Icons.contacts_outlined,
                    title: 'Liên hệ khẩn cấp (Stringee)',
                    subtitle: 'Quản lý người thân & số PCCC gọi tự động',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmergencyContactsPage()),
                      );
                    },
                  ),

                  const _SettingsDivider(),

                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Vị trí & Địa chỉ khẩn cấp',
                    subtitle: 'Địa chỉ AI đọc qua điện thoại khi có cháy',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmergencyLocationPage()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // ===============================================
              // APPLICATION
              // ===============================================

              const _SectionTitle(
                title: 'Ứng dụng',
              ),

              const SizedBox(
                height: 8,
              ),

              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons
                        .info_outline_rounded,
                    title:
                    'Về IGNIVO',
                    subtitle:
                    'Thông tin ứng dụng',
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(
                height: 28,
              ),

              // ===============================================
              // LOGOUT
              // ===============================================

              SizedBox(
                height: 52,
                child:
                OutlinedButton.icon(
                  onPressed: () =>
                      _logout(
                        context,
                        authService,
                      ),
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    AppColors.danger,
                    side: const BorderSide(
                      color:
                      AppColors.danger,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        14,
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons
                        .logout_rounded,
                  ),
                  label: const Text(
                    'Đăng xuất',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              const Center(
                child: Text(
                  'IGNIVO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color: AppColors
                        .textTertiary,
                  ),
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              const Center(
                child: Text(
                  'An toàn hôm nay, bình yên ngày mai',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors
                        .textTertiary,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout(
      BuildContext context,
      AuthService authService,
      ) async {
    final shouldLogout =
    await showDialog<bool>(
      context: context,
      builder: (
          dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Đăng xuất',
          ),
          content:
          const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi IGNIVO?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
              const Text(
                'Hủy',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
              const Text(
                'Đăng xuất',
                style: TextStyle(
                  color:
                  AppColors.danger,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await authService.logout();

    // Không Navigator thủ công.
    // AuthWrapper sẽ tự chuyển về LoginPage.
  }
}

// ============================================================================
// ACCOUNT CARD
// ============================================================================

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onTap,
  });

  final String name;
  final String email;
  final String photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(20),
        child: Container(
          padding:
          const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: AppColors
                  .backgroundBlueSoft,
            ),
          ),
          child: Row(
            children: [
              _Avatar(
                name: name,
                photoUrl: photoUrl,
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      name.isNotEmpty
                          ? name
                          : 'Người dùng IGNIVO',
                      style:
                      const TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight
                            .w700,
                        color: AppColors
                            .textPrimary,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      email.isNotEmpty
                          ? email
                          : 'Xem thông tin cá nhân',
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 12,
                        color: AppColors
                            .textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color: AppColors
                    .textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoUrl,
  });

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor:
        AppColors.backgroundBlueSoft,
        backgroundImage:
        NetworkImage(photoUrl),
      );
    }

    final firstLetter =
    name.isNotEmpty
        ? name
        .substring(0, 1)
        .toUpperCase()
        : 'I';

    return CircleAvatar(
      radius: 28,
      backgroundColor:
      AppColors.backgroundBlueSoft,
      child: Text(
        firstLetter,
        style: const TextStyle(
          fontSize: 20,
          fontWeight:
          FontWeight.w700,
          color:
          AppColors.primaryDark,
        ),
      ),
    );
  }
}

// ============================================================================
// SETTINGS GROUP
// ============================================================================

class _SettingsGroup
    extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          AppColors.backgroundBlueSoft,
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}

// ============================================================================
// SETTINGS TILE
// ============================================================================

class _SettingsTile
    extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
          AppColors.backgroundBlueSoft,
          borderRadius:
          BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
          AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style:
        const TextStyle(
          fontSize: 14,
          fontWeight:
          FontWeight.w600,
          color:
          AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
        const TextStyle(
          fontSize: 11,
          color:
          AppColors.textTertiary,
        ),
      ),
      trailing:
      const Icon(
        Icons.chevron_right_rounded,
        color:
        AppColors.textTertiary,
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style:
      const TextStyle(
        fontSize: 12,
        fontWeight:
        FontWeight.w700,
        letterSpacing: 0.7,
        color:
        AppColors.textTertiary,
      ),
    );
  }
}

class _SettingsDivider
    extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 72,
      color:
      AppColors.backgroundBlueSoft,
    );
  }
}
