import 'package:flutter/material.dart';
import '../../core/models/push_notification_model.dart';
import '../../core/services/messaging_service.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/ignivo_sheet.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../fireguard/face_widgets.dart';
import '../fireguard/monitoring_controller.dart';
import '../fireguard/people_page.dart';
import '../../core/services/face_notification_service.dart';
import '../../core/services/app_auth_controller.dart';
import '../../core/services/multi_system_monitoring_coordinator.dart';
import '../../core/services/system_session_manager.dart';
import '../systems/systems_page.dart';
import 'diagnostics_page.dart';
import 'emergency_contacts_page.dart';
import 'emergency_location_page.dart';
import 'ignivo_about_page.dart';

class GuardSettingsPage extends StatelessWidget {
  const GuardSettingsPage({
    super.key,
    required this.sessionController,
    required this.monitoringController,
    this.sessionManager,
    this.authController,
    this.coordinator,
    this.onOpenDiagnostics,
  });

  final SystemSessionController sessionController;
  final MonitoringController monitoringController;
  final SystemSessionManager? sessionManager;
  final AppAuthController? authController;
  final MultiSystemMonitoringCoordinator? coordinator;
  final VoidCallback? onOpenDiagnostics;

  void _confirmSignOutAccount(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất tài khoản IGNIVO?'),
        content: const Text(
          'Toàn bộ phiên làm việc của các hệ thống trên thiết bị này sẽ được đóng lại và bạn sẽ quay về màn hình đăng nhập Cloud.',
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
            child: const Text('Đăng xuất Cloud'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authController?.signOut();
    }
  }

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
      if (sessionManager != null && sessionManager!.activeSystemId != null) {
        await sessionManager!.logoutSystem(sessionManager!.activeSystemId!);
      } else {
        await sessionController.logout();
      }
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
      if (sessionManager != null) {
        final currentSysId = sessionManager!.activeSystemId ??
            sessionManager!.systems
                .where((s) => s.guardUrl == sessionController.guardUrl)
                .firstOrNull
                ?.systemId;
        if (currentSysId != null) {
          await sessionManager!.removeSystem(currentSysId);
        }
      }
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
    final cloudEmail = authController?.currentUserEmail;
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
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
                      radius: 28,
                      backgroundColor: isDark
                          ? BrandTokens.darkBrandTint
                          : BrandTokens.brandTint,
                      child: Text(
                        initials.isNotEmpty ? initials : 'MA',
                        style: TextStyle(
                          fontSize: 18,
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
                          if (cloudEmail != null) ...[
                            Text(
                              cloudEmail,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hệ thống: $name',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? BrandTokens.darkTextSecondary
                                    : BrandTokens.textSecondary,
                              ),
                            ),
                          ] else ...[
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
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
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
                      Icons.contacts_rounded,
                      color: isDark ? Colors.red.shade300 : BrandTokens.criticalFg,
                      background: isDark
                          ? Colors.red.shade900.withValues(alpha: 0.25)
                          : Colors.red.shade50,
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
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmergencyContactsPage(api: sessionController.api),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.location_on_rounded,
                      color: isDark ? Colors.amber.shade300 : BrandTokens.stitchWarningFg,
                      background: isDark
                          ? Colors.amber.shade900.withValues(alpha: 0.25)
                          : Colors.amber.shade50,
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
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmergencyLocationPage(api: sessionController.api),
                        ),
                      );
                    },
                  ),
                  if (sessionController.canAccessFaces) ...[
                    const Divider(height: 1, indent: 68, endIndent: 16),
                    ListTile(
                      leading: _buildLeadingIcon(
                        context,
                        Icons.face_retouching_natural_rounded,
                        color: isDark ? Colors.purple.shade200 : Colors.purple.shade700,
                        background: isDark
                            ? Colors.purple.shade900.withValues(alpha: 0.25)
                            : Colors.purple.shade50,
                      ),
                      title: const Text(
                        'Hồ sơ & Nhận diện gương mặt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        isOwnerOrAdmin
                            ? 'Đăng ký hồ sơ, mẫu góc mặt và theo dõi xác minh'
                            : 'Xem hồ sơ gương mặt và lịch sử đối chiếu (BR-24)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PeoplePage(
                              api: sessionController.api,
                              cameras: monitoringController.cameras,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 68, endIndent: 16),
                    ListTile(
                      leading: _buildLeadingIcon(
                        context,
                        Icons.notifications_active_outlined,
                        color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade700,
                        background: isDark
                            ? Colors.indigo.shade900.withValues(alpha: 0.25)
                            : Colors.indigo.shade50,
                      ),
                      title: const Text(
                        'Thông báo nhận diện gương mặt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: ListenableBuilder(
                        listenable: FaceNotificationService.instance,
                        builder: (context, _) {
                          final k = FaceNotificationService.instance.notifyKnown ? 'Bật' : 'Tắt';
                          final u = FaceNotificationService.instance.notifyUnknown ? 'Bật' : 'Tắt';
                          return Text(
                            'Người quen: $k · Chưa khớp: $u',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      trailing: const Icon(Icons.tune_rounded, size: 20),
                      onTap: () => showFaceNotificationSettingsSheet(context),
                    ),
                  ],
                  if (isOwnerOrAdmin) ...[
                    const Divider(height: 1, indent: 68, endIndent: 16),
                    ListTile(
                      leading: _buildLeadingIcon(
                        context,
                        Icons.campaign_outlined,
                        color: BrandTokens.stitchCritical,
                        background: isDark
                            ? Colors.red.shade900.withValues(alpha: 0.25)
                            : Colors.red.shade50,
                      ),
                      title: const Text(
                        'Kiểm tra thông báo cháy ngoài app',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Phát thử còi rung và thông báo Heads-Up khẩn cấp ra màn hình khóa',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.play_circle_outline_rounded, size: 22, color: BrandTokens.stitchCritical),
                      onTap: () async {
                        // 1. Đảm bảo token FCM của thiết bị đã được đăng ký với Pi
                        final api = sessionController.api;
                        final regOk = await MessagingService.instance.registerWithApi(api);

                        // 2. Yêu cầu Pi backend bắn test push qua FCM
                        final res = await api.triggerTestPush();
                        final successCount = (res?['success_count'] as num?)?.toInt() ?? 0;

                        if (res != null && res['ok'] == true && successCount > 0) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🔥 Pi đã gửi thông báo FCM tới $successCount thiết bị!'),
                                backgroundColor: BrandTokens.stitchSafe,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } else {
                          // Nếu Pi chưa gửi được FCM thực tế, fallback sang local test
                          MessagingService.instance.dispatchPushEvent(
                            IgnivoPushNotification(
                              id: 'test_fire_${DateTime.now().millisecondsSinceEpoch}',
                              category: PushNotificationCategory.fireEmergency,
                              title: '🔥 [TEST] PHÁT HIỆN NGỌN LỬA (Phòng khách)',
                              body: 'AI thị giác phát hiện ngọn lửa bốc lên [#99] (Độ tin cậy: 98%). Nhấn để kiểm tra camera ngay lập tức!',
                              incidentId: 99,
                              triggerType: 'FIRE',
                              severity: 'critical',
                              area: 'Phòng khách',
                              timestamp: DateTime.now(),
                            ),
                          );
                          if (context.mounted) {
                            final errMsg = (res?['errors'] as List?)?.join(', ');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  regOk
                                      ? '🚨 Đã đăng ký thiết bị với Pi & phát thông báo thử nghiệm!${errMsg != null && errMsg.isNotEmpty ? ' ($errMsg)' : ''}'
                                      : '🚨 Đang kết nối thiết bị với Pi. Đã phát thông báo thử nghiệm ra OS!',
                                ),
                                backgroundColor: BrandTokens.stitchCritical,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.info_outline_rounded,
                      color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                      background: isDark
                          ? BrandTokens.darkBrandTint
                          : BrandTokens.brandTint,
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
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warningStyle.background,
                borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                border: Border.all(color: warningStyle.border, width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: warningStyle.foreground.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.volume_up_rounded,
                      color: warningStyle.foreground,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            height: 1.4,
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
                  if (sessionManager != null) ...[
                    ListTile(
                      key: const Key('settings-switch-system-tile'),
                      leading: _buildLeadingIcon(
                        context,
                        Icons.hub_rounded,
                        color: isDark ? Colors.teal.shade300 : Colors.teal.shade700,
                        background: isDark
                            ? Colors.teal.shade900.withValues(alpha: 0.25)
                            : Colors.teal.shade50,
                      ),
                      title: Row(
                        children: [
                          const Text(
                            'Đổi hệ thống giám sát',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? BrandTokens.darkBrandTint
                                  : BrandTokens.brandTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${sessionManager!.systems.length} hệ thống',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? BrandTokens.darkPrimary
                                    : BrandTokens.brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Đang giám sát: ${sessionController.systemName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SystemsPage(
                              sessionManager: sessionManager!,
                              authController: authController,
                              coordinator: coordinator,
                              canPop: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 68, endIndent: 16),
                    ListTile(
                      key: const Key('settings-members-tile'),
                      leading: _buildLeadingIcon(
                        context,
                        Icons.people_alt_rounded,
                        color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
                        background: isDark
                            ? Colors.indigo.shade900.withValues(alpha: 0.25)
                            : Colors.indigo.shade50,
                      ),
                      title: const Text(
                        'Thành viên & Phân quyền',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Tính năng chưa triển khai',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () => showFeatureNotImplementedDialog(context),
                    ),
                    const Divider(height: 1, indent: 68, endIndent: 16),
                  ],
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.monitor_heart_rounded,
                      color: isDark ? BrandTokens.stitchDarkOnlineFg : BrandTokens.stitchOnlineFg,
                      background: isDark
                          ? BrandTokens.stitchDarkOnlineBg
                          : BrandTokens.stitchOnlineBg,
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
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  ListTile(
                    leading: _buildLeadingIcon(
                      context,
                      Icons.router_rounded,
                      color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                      background: isDark
                          ? BrandTokens.darkSurfaceVariant
                          : Colors.blueGrey.withValues(alpha: 0.1),
                    ),
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
                        style: TextStyle(color: criticalColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Logout Buttons
            if (authController != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: criticalColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        BrandTokens.buttonRadius,
                      ),
                    ),
                  ),
                  onPressed: () => _confirmSignOutAccount(context),
                  icon: const Icon(Icons.cloud_off_rounded),
                  label: const Text(
                    'Đăng xuất IGNIVO Cloud',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: criticalColor,
                  ),
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Đăng xuất phiên Pi hiện tại'),
                ),
              ),
            ] else ...[
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
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Đăng xuất tài khoản',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
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
    ),
  ),
);
}

  Widget _buildLeadingIcon(
    BuildContext context,
    IconData icon, {
    Color? color,
    Color? background,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ?? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary);
    final bg = background ?? (isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 20,
        color: fg,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.2,
          color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
        ),
      ),
    );
  }
}
