import 'package:flutter/material.dart';
import '../../core/models/system_record.dart';
import '../../core/services/app_auth_controller.dart';
import '../../core/services/multi_system_monitoring_coordinator.dart';
import '../../core/services/system_session_manager.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../auth/system_login_page.dart';
import '../settings/connection_setup_page.dart';
import 'system_members_page.dart';
import 'invitations_page.dart';


class SystemsPage extends StatefulWidget {
  const SystemsPage({
    super.key,
    required this.sessionManager,
    this.authController,
    this.coordinator,
    this.canPop = false,
    this.onBack,
    this.onSystemSelected,
  });

  final SystemSessionManager sessionManager;
  final AppAuthController? authController;
  final MultiSystemMonitoringCoordinator? coordinator;
  final bool canPop;
  final VoidCallback? onBack;
  final void Function(SystemRecord system)? onSystemSelected;

  @override
  State<SystemsPage> createState() => _SystemsPageState();
}

class _SystemsPageState extends State<SystemsPage> {
  @override
  void initState() {
    super.initState();
    widget.sessionManager.addListener(_onChanged);
    widget.coordinator?.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.sessionManager.removeListener(_onChanged);
    widget.coordinator?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openAddSystem() async {
    // Tạo controller tạm thời cho màn hình cấu hình
    final tempController = SystemSessionController();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConnectionSetupPage(
          sessionController: tempController,
          sessionManager: widget.sessionManager,
          canPop: true,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã liên kết hệ thống thành công!'),
          backgroundColor: BrandTokens.stitchSafe,
        ),
      );
    }
  }

  Future<void> _switchToSystem(SystemRecord system) async {
    await widget.sessionManager.switchSystem(system.systemId);

    if (!mounted) return;

    final controller = widget.sessionManager.activeController;
    if (controller != null && !controller.isAuthenticated) {
      // Yêu cầu đăng nhập vào Pi nếu chưa có phiên hợp lệ
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SystemLoginPage(sessionController: controller),
        ),
      );
    }

    if (!mounted) return;

    if (widget.onSystemSelected != null) {
      widget.onSystemSelected!(system);
    } else if (widget.canPop && Navigator.canPop(context)) {
      Navigator.pop(context, system);
    }
  }

  Future<void> _confirmRemoveSystem(SystemRecord system) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ hệ thống'),
        content: Text(
          'Bạn có chắc muốn gỡ bỏ "${system.systemName}" khỏi tài khoản? '
          'Dữ liệu camera và sự cố trên Edge Box vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: BrandTokens.stitchCriticalFg,
            ),
            child: const Text('Gỡ bỏ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.sessionManager.removeSystem(system.systemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gỡ hệ thống "${system.systemName}"'),
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOutAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất tài khoản'),
        content: const Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản Ignivo Cloud trên thiết bị này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && widget.authController != null) {
      await widget.authController!.signOut();
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final systems = widget.sessionManager.systems;
    final activeId = widget.sessionManager.activeSystemId;
    final canDirectlyPop = Navigator.canPop(context);
    final canGoBack = widget.canPop || widget.onBack != null || canDirectlyPop;

    return PopScope(
      canPop: !canGoBack || canDirectlyPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hệ thống giám sát'),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBack,
                )
              : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            tooltip: 'Lời mời tham gia hệ thống',
            onPressed: _openInvitationsPage,
          ),
          if (widget.authController != null)
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Đăng xuất tài khoản Cloud',
              onPressed: _confirmSignOutAccount,
            ),
        ],

      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User info header
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? BrandTokens.darkBrandTint
                            : BrandTokens.brandTint)
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(
                      color: (isDark
                              ? BrandTokens.darkBorder
                              : BrandTokens.border)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: BrandTokens.brandPrimary,
                        radius: 20,
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.authController?.currentUserEmail ??
                                  'Tài khoản Ignivo',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${systems.length} hệ thống liên kết',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? BrandTokens.darkTextSecondary
                                    : BrandTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _openAddSystem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm Pi'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),

                // Systems list or empty state
                Expanded(
                  child: systems.isEmpty
                      ? _buildEmptyState(context, isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: systems.length,
                          itemBuilder: (context, index) {
                            final system = systems[index];
                            final isActive = system.systemId == activeId;
                            final controller = widget.sessionManager
                                .getController(system.systemId);
                            final hasAlerts = widget.coordinator
                                    ?.inactiveIncidents[system.systemId]
                                    ?.isNotEmpty ??
                                false;

                            return _buildSystemCard(
                              context,
                              system: system,
                              isActive: isActive,
                              controller: controller,
                              hasAlerts: hasAlerts,
                              isDark: isDark,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  void _openInvitationsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvitationsPage(
          sessionManager: widget.sessionManager,
          userEmail: widget.authController?.currentUserEmail,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: BrandTokens.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hub_outlined,
                size: 64,
                color: BrandTokens.brandPrimary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Chào mừng bạn đến với IGNIVO!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tài khoản Cloud của bạn hiện chưa có hệ thống nào. Bạn có thể ghép nối thiết bị mới hoặc kiểm tra các lời mời quản lý được chia sẻ.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? BrandTokens.darkTextSecondary
                        : BrandTokens.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openAddSystem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ghép nối Edge Box mới'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openInvitationsPage,
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Xem lời mời được chia sẻ'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCard(
    BuildContext context, {
    required SystemRecord system,
    required bool isActive,
    required SystemSessionController? controller,
    required bool hasAlerts,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final isAuthed = controller?.isAuthenticated ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        side: BorderSide(
          color: hasAlerts
              ? BrandTokens.stitchCriticalFg
              : isActive
                  ? BrandTokens.brandPrimary
                  : (isDark ? BrandTokens.darkBorder : BrandTokens.border),
          width: isActive || hasAlerts ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        onTap: () => _switchToSystem(system),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isActive
                        ? BrandTokens.brandPrimary
                        : (isDark
                            ? BrandTokens.darkTextSecondary
                            : BrandTokens.textSecondary),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      system.systemName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasAlerts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: BrandTokens.stitchCriticalBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            size: 14,
                            color: BrandTokens.stitchCriticalFg,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'CẢNH BÁO',
                            style: TextStyle(
                              color: BrandTokens.stitchCriticalFg,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BrandTokens.stitchDarkOnlineBg
                            : BrandTokens.stitchOnlineBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ĐANG CHỌN',
                        style: TextStyle(
                          color: isDark
                              ? BrandTokens.stitchDarkOnlineFg
                              : BrandTokens.stitchOnlineFg,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'members') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SystemMembersPage(system: system),
                          ),
                        );
                      } else if (val == 'remove') {
                        _confirmRemoveSystem(system);
                      } else if (val == 'logout') {
                        widget.sessionManager.logoutSystem(system.systemId);
                      }
                    },
                    itemBuilder: (context) => [
                      if (system.canManageMembers)
                        const PopupMenuItem(
                          value: 'members',
                          child: Row(
                            children: [
                              Icon(Icons.group_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Quản lý thành viên'),
                            ],
                          ),
                        ),
                      if (isAuthed)
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18),
                              SizedBox(width: 8),
                              Text('Đăng xuất khỏi Pi'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Gỡ hệ thống',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),

                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 14,
                    color: isDark
                        ? BrandTokens.darkTextSecondary
                        : BrandTokens.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      system.guardUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: isDark
                            ? BrandTokens.darkTextSecondary
                            : BrandTokens.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (system.location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: isDark
                          ? BrandTokens.darkTextSecondary
                          : BrandTokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        system.location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: system.role == 'OWNER'
                              ? (isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint)
                              : (isDark ? BrandTokens.darkSurfaceVariant : BrandTokens.background),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: system.role == 'OWNER'
                                ? BrandTokens.brandPrimary.withValues(alpha: 0.3)
                                : (isDark ? BrandTokens.darkBorder : BrandTokens.border),
                          ),
                        ),
                        child: Text(
                          system.roleDisplayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: system.role == 'OWNER' ? BrandTokens.brandPrimary : null,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),
                      Text(
                        isAuthed ? 'Đã xác thực' : 'Chưa đăng nhập Pi',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAuthed
                              ? (isDark
                                  ? BrandTokens.stitchDarkOnlineFg
                                  : BrandTokens.stitchOnlineFg)
                              : Colors.amber.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!isActive)
                    TextButton.icon(
                      onPressed: () => _switchToSystem(system),
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: const Text('Chuyển tới'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
