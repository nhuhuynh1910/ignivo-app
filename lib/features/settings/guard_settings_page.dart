import 'package:flutter/material.dart';
import '../../core/services/system_session_controller.dart';
import '../fireguard/monitoring_controller.dart';
import 'diagnostics_page.dart';
import 'emergency_contacts_page.dart';
import 'emergency_location_page.dart';

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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
    final isOwnerOrAdmin = sessionController.isOwnerOrAdmin;
    final role = sessionController.role ?? 'USER';
    final name = sessionController.fullName ?? sessionController.username ?? 'Người dùng';
    final phone = sessionController.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Account Info Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.person, size: 28, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(phone, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOwnerOrAdmin
                                ? Colors.purple.withValues(alpha: 0.12)
                                : Colors.blueGrey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOwnerOrAdmin ? 'VAI TRÒ: $role (TOÀN QUYỀN)' : 'VAI TRÒ: $role (XỬ LÝ SỰ CỐ)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOwnerOrAdmin ? Colors.purple.shade700 : Colors.blueGrey.shade800,
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
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.contacts_outlined, color: Colors.blue),
                  title: const Text('Người liên hệ khẩn cấp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        builder: (_) => EmergencyContactsPage(api: sessionController.api),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Colors.red),
                  title: const Text('Địa chỉ khẩn cấp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    'Vị trí, toà nhà, số tầng để tổng đài cung cấp cho PCCC',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmergencyLocationPage(api: sessionController.api),
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
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade400, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.volume_up_outlined, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cảnh báo hoạt động khi mở ứng dụng',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Còi hú và rung hoạt động khi ứng dụng đang mở hoặc chạy đa nhiệm. Hãy bật âm lượng chuông để đảm bảo nghe thấy âm báo trong trường hợp có cháy.',
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
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
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined, color: Colors.teal),
                  title: const Text('Chẩn đoán hệ thống Edge Pi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Xem trạng thái CPU, NPU Hailo, AI FPS, WebSocket', style: TextStyle(fontSize: 12)),
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
                  leading: const Icon(Icons.router_outlined, color: Colors.indigo),
                  title: const Text('Địa chỉ FireGuard Edge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(sessionController.guardUrl, style: const TextStyle(fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () => _confirmDisconnect(context),
                    child: const Text('Đổi kết nối', style: TextStyle(color: Colors.red)),
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
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
