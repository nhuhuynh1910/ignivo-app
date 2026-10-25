import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_avatar.dart';
import '../system/system_detail_page.dart';
import 'edge_connection_page.dart';
import 'emergency_contacts_page.dart';
import 'emergency_location_page.dart';
import 'ignivo_about_page.dart';
import 'personal_info_page.dart';
import 'security_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? BrandTokens.darkBackground : BrandTokens.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'Cài đặt & Tài khoản',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestoreService.watchUserProfile(uid),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};

          final name = data['name']?.toString().trim() ?? '';
          final email = data['email']?.toString().trim() ??
              authService.currentUserEmail ??
              '';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // ===============================================
                  // MODERN GRADIENT ACCOUNT BANNER
                  // ===============================================
                  _AccountGradientHeader(
                    name: name,
                    email: email,
                    data: data,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PersonalInfoPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ===============================================
                  // SECTION: TÀI KHOẢN
                  // ===============================================
                  _SectionTitle(title: 'Tài khoản & Hồ sơ', isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCardGroup(
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Thông tin cá nhân',
                        subtitle: 'Cập nhật tên, email, số điện thoại & ảnh đại diện',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PersonalInfoPage(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.shield_outlined,
                        title: 'Bảo mật & Đăng nhập',
                        subtitle: 'Mật khẩu và phương thức xác thực',
                        isDark: isDark,
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

                  const SizedBox(height: 22),

                  // ===============================================
                  // SECTION: IGNIVO SMART SAFETY
                  // ===============================================
                  _SectionTitle(title: 'Hệ thống IGNIVO Edge Box', isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCardGroup(
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.memory_rounded,
                        title: 'Quản lý thiết bị Edge Box',
                        subtitle: 'Trạng thái Raspberry Pi 5 & AI Hailo-8L',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SystemDetailPage(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.lan_rounded,
                        title: 'Kết nối hệ thống Pi',
                        subtitle: 'FireEye, FireGuard và Tailscale VPN',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EdgeConnectionPage(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.phone_forwarded_rounded,
                        title: 'Liên hệ khẩn cấp (Stringee Call)',
                        subtitle: 'Quản lý danh bạ gọi điện tự động cho PCCC & người thân',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EmergencyContactsPage(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.place_rounded,
                        title: 'Vị trí & Địa chỉ khẩn cấp',
                        subtitle: 'Địa chỉ AI thông báo tới cơ quan PCCC khi có cháy',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EmergencyLocationPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ===============================================
                  // SECTION: ỨNG DỤNG
                  // ===============================================
                  _SectionTitle(title: 'Ứng dụng & Hỗ trợ', isDark: isDark),
                  const SizedBox(height: 8),
                  _SettingsCardGroup(
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Giới thiệu IGNIVO',
                        subtitle: 'Phiên bản ứng dụng, điều khoản và giấy phép',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const IgnivoAboutPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ===============================================
                  // LOGOUT BUTTON
                  // ===============================================
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _logout(context, authService),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Đăng xuất tài khoản',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Column(
                      children: [
                        Text(
                          'IGNIVO · Smart Safety System',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: isDark ? BrandTokens.darkTextTertiary : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phát hiện sớm. Bảo vệ kịp thời.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? BrandTokens.darkTextTertiary : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context, AuthService authService) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi IGNIVO?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await authService.logout();
    }
  }
}

// ============================================================================
// ACCOUNT GRADIENT HEADER
// ============================================================================

class _AccountGradientHeader extends StatelessWidget {
  const _AccountGradientHeader({
    required this.name,
    required this.email,
    required this.data,
    required this.onTap,
  });

  final String name;
  final String email;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: BrandTokens.primaryGradient,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: BrandTokens.brandNavy.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IgnivoUserAvatar(
                  name: name,
                  data: data,
                  radius: 32,
                  showBorder: true,
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Người dùng IGNIVO',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isNotEmpty ? email : 'Chưa cập nhật email',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Chỉnh sửa hồ sơ ›',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SETTINGS GROUP & TILES
// ============================================================================

class _SettingsCardGroup extends StatelessWidget {
  const _SettingsCardGroup({
    required this.children,
    required this.isDark,
  });

  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? BrandTokens.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? BrandTokens.darkTextTertiary : AppColors.textTertiary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? BrandTokens.darkTextTertiary : AppColors.textTertiary,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.isDark,
  });

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.brandNavy,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 70,
      color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
    );
  }
}
