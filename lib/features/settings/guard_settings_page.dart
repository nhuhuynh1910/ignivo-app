import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/ignivo_sheet.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../fireguard/monitoring_controller.dart';
import 'diagnostics_page.dart';
import 'emergency_contacts_page.dart';
import 'emergency_location_page.dart';
import 'ignivo_about_page.dart';

class GuardSettingsPage extends StatelessWidget {
  const GuardSettingsPage({
    super.key,
    required this.sessionController,
    required this.monitoringController,
    this.onOpenDiagnostics,
  });

  final SystemSessionController sessionController;
  final MonitoringController monitoringController;
  final VoidCallback? onOpenDiagnostics;

  void _confirmLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất tài khoản?'),
        content: const Text(
          'Phiên làm việc sẽ bị xóa khỏi bộ nhớ RAM. Bạn sẽ cần nhập lại mật khẩu và mã hệ thống để đăng nhập lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? BrandTokens.darkCriticalFg
                  : BrandTokens.criticalFg,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sessionController.logout();
    }
  }

  void _confirmDisconnect(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi kết nối hệ thống Pi?'),
        content: const Text(
          'Kết nối hiện tại với Pi sẽ được ngắt và phiên làm việc sẽ được xóa. Bạn sẽ quay về màn hình Cài đặt kết nối ban đầu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? BrandTokens.darkCriticalFg
                  : BrandTokens.criticalFg,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ngắt kết nối'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sessionController.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOwnerOrAdmin = sessionController.isOwnerOrAdmin;
    final role = sessionController.role ?? 'USER';
    final name =
        sessionController.fullName ??
        sessionController.username ??
        'Người dùng';
    final phone = sessionController.phoneNumber ?? '';
    final warningStyle = StatusStyle.warning(isDark: isDark);
    final criticalColor = isDark
        ? BrandTokens.darkCriticalFg
        : BrandTokens.criticalFg;

    final initials = name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();

    return Scaffold(
      body: IgnivoPageBody(
        header: IgnivoPageHeader(
          title: 'Cài đặt',
          subtitle: 'Tài khoản và hệ thống',
          systemName: sessionController.systemName,
          avatarInitials: initials.isNotEmpty ? initials : 'MA',
          onTapSystem: () {
            showIgnivoSystemSheet(
              context: context,
              systemName: sessionController.systemName,
              address: sessionController.guardUrl,
              isConnected: !monitoringController.stale,
              cameraCount: monitoringController.cameras.length,
              onDiagnostics: onOpenDiagnostics ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DiagnosticsPage(
                          monitoringController: monitoringController,
                          sessionController: sessionController,
                        ),
                      ),
                    );
                  },
              onChangeConnection: () => _confirmDisconnect(context),
            );
          },
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Account Info Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                side: BorderSide(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: isDark
                          ? BrandTokens.darkBrandTint
                          : BrandTokens.brandTint,
                      child: Text(
                        initials.isNotEmpty ? initials : 'MA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? BrandTokens.darkPrimary
                              : BrandTokens.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? BrandTokens.darkTextSecondary
                                    : BrandTokens.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (isOwnerOrAdmin
                                        ? Colors.purple.shade900.withValues(
                                            alpha: 0.3,
                                          )
                                        : BrandTokens.darkSurfaceVariant)
                                  : (isOwnerOrAdmin
                                        ? Colors.purple.withValues(alpha: 0.12)
                                        : Colors.blueGrey.withValues(
                                            alpha: 0.12,
                                          )),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOwnerOrAdmin
                                  ? 'VAI TRÒ: $role (TOÀN QUYỀN)'
                                  : 'VAI TRÒ: $role (XỬ LÝ SỰ CỐ)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? (isOwnerOrAdmin
                                          ? Colors.purple.shade200
                                          : BrandTokens.darkTextSecondary)
                                    : (isOwnerOrAdmin
                                          ? Colors.purple.shade700
                                          : Colors.blueGrey.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Emergency Setup & Contacts
            _buildSectionTitle(context, 'Cấu hình khẩn cấp'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                side: BorderSide(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.contacts_outlined,
                    ),
                    title: const Text(
                      'Người liên hệ khẩn cấp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isOwnerOrAdmin
                          ? 'Cấu hình danh bạ gọi điện người thân & PCCC'
                          : 'Xem danh bạ người thân & PCCC đã thiết lập',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmergencyContactsPage(api: sessionController.api),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.location_on_outlined,
                    ),
                    title: const Text(
                      'Địa chỉ khẩn cấp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Vị trí, toà nhà, số tầng để tổng đài cung cấp cho PCCC',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmergencyLocationPage(api: sessionController.api),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.info_outline,
                    ),
                    title: const Text(
                      'Giới thiệu IGNIVO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Phát hiện sớm. Bảo vệ kịp thời.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
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
            ),
            const SizedBox(height: 20),

            // 3. Audio & Alarm Explanation
            _buildSectionTitle(context, 'Cảnh báo âm thanh & thiết bị'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: warningStyle.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: warningStyle.border, width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    color: warningStyle.foreground,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cảnh báo hoạt động khi mở ứng dụng',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Còi hú và rung hoạt động khi ứng dụng đang mở hoặc chạy đa nhiệm. Hãy bật âm lượng chuông để đảm bảo nghe thấy âm báo trong trường hợp có cháy.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? BrandTokens.darkTextSecondary
                                : BrandTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. System Diagnostics & Connection
            _buildSectionTitle(context, 'Hệ thống & Chẩn đoán'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                side: BorderSide(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.monitor_heart_outlined,
                    ),
                    title: const Text(
                      'Chẩn đoán hệ thống Edge Pi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Xem trạng thái CPU, NPU Hailo, AI FPS, WebSocket',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DiagnosticsPage(
                            monitoringController: monitoringController,
                            sessionController: sessionController,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _buildLeadingIcon(context, Icons.router_outlined),
                    title: const Text(
                      'Địa chỉ FireGuard Edge',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      sessionController.guardUrl,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () => _confirmDisconnect(context),
                      child: Text(
                        'Đổi kết nối',
                        style: TextStyle(color: criticalColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: criticalColor,
                  side: BorderSide(color: criticalColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BrandTokens.buttonRadius,
                    ),
                  ),
                ),
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Đăng xuất tài khoản',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'IGNIVO · Smart Safety',
                style: TextStyle(
                  color: isDark
                      ? BrandTokens.darkTextSecondary
                      : BrandTokens.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
