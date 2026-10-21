import 'package:flutter/material.dart';
import '../../core/models/system_record.dart';
import '../../core/services/app_auth_controller.dart';
import '../../core/services/multi_system_monitoring_coordinator.dart';
import '../../core/services/system_session_manager.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../navigation/ignivo_shell.dart';
import '../auth/system_login_page.dart';
import '../fireguard/incident_page.dart';
import '../settings/connection_setup_page.dart';
import '../settings/ignivo_about_page.dart';
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
  int _currentTab = 0;

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

  Future<void> _switchToSystem(SystemRecord system, {bool openMonitoring = false}) async {
    await widget.sessionManager.switchSystem(system.systemId);

    if (!mounted) return;

    final controller = widget.sessionManager.activeController;
    if (controller != null && !controller.isAuthenticated) {
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
    } else if (openMonitoring && controller != null && controller.isAuthenticated) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IgnivoShell(
            sessionController: controller,
            sessionManager: widget.sessionManager,
            coordinator: widget.coordinator,
            authController: widget.authController,
          ),
        ),
      );
      if (mounted) setState(() {});
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

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  List<Map<String, dynamic>> _collectAllAlerts() {
    final List<Map<String, dynamic>> all = [];
    final manager = widget.sessionManager;
    final coordinator = widget.coordinator;

    // 1. Inactive incidents from coordinator
    if (coordinator != null) {
      for (final entry in coordinator.inactiveIncidents.entries) {
        final sysId = entry.key;
        final sysName = manager.systems
            .firstWhere(
              (s) => s.systemId == sysId,
              orElse: () => SystemRecord(
                systemId: sysId,
                systemName: 'Hệ thống $sysId',
                guardUrl: '',
                addedAt: DateTime.now(),
              ),
            )
            .systemName;
        for (final inc in entry.value) {
          all.add({
            ...inc,
            '_systemId': sysId,
            '_systemName': sysName,
          });
        }
      }
    }

    return all;
  }

  void _openIncidentDetail(Map<String, dynamic> inc) {
    final sysId = inc['_systemId'] as String?;
    final controller = sysId != null ? widget.sessionManager.getController(sysId) : null;
    final id = (inc['id'] ?? inc['incident_id']) as int? ?? 0;
    if (id <= 0) return;

    if (controller != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FireguardIncidentPage(
            incidentId: id,
            api: controller.api,
            coordinator: null,
          ),
        ),
      );
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

    String appBarTitle;
    switch (_currentTab) {
      case 1:
        appBarTitle = 'Trung tâm báo động';
        break;
      case 2:
        appBarTitle = 'Tài khoản & Cài đặt';
        break;
      case 0:
      default:
        appBarTitle = 'Hệ thống giám sát';
        break;
    }

    return PopScope(
      canPop: !canGoBack || canDirectlyPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBack,
                )
              : null,
          actions: [
            if (_currentTab == 0) ...[
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Ghép nối Edge Box mới',
                onPressed: _openAddSystem,
              ),
              IconButton(
                icon: const Icon(Icons.mail_outline_rounded),
                tooltip: 'Lời mời tham gia hệ thống',
                onPressed: _openInvitationsPage,
              ),
            ] else if (_currentTab == 1) ...[
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Làm mới cảnh báo',
                onPressed: () => setState(() {}),
              ),
            ] else if (_currentTab == 2) ...[
              if (widget.authController != null)
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Đăng xuất tài khoản Cloud',
                  onPressed: _confirmSignOutAccount,
                ),
            ],
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (idx) => setState(() => _currentTab = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.devices_outlined),
              selectedIcon: Icon(Icons.devices_rounded),
              label: 'Hệ thống',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Báo động',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: switch (_currentTab) {
                1 => _buildAlertsTab(context, theme, isDark),
                2 => _buildMeTab(context, theme, isDark, systems),
                _ => _buildSystemsTab(context, theme, isDark, systems, activeId),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemsTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<SystemRecord> systems,
    String? activeId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User info header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: (isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint)
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: (isDark ? BrandTokens.darkBorder : BrandTokens.border)
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
                      widget.authController?.currentUserEmail ?? 'Tài khoản Ignivo',
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
                    final controller =
                        widget.sessionManager.getController(system.systemId);
                    final hasAlerts = widget.coordinator
                            ?.inactiveIncidents[system.systemId]?.isNotEmpty ??
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
    );
  }

  Widget _buildAlertsTab(BuildContext context, ThemeData theme, bool isDark) {
    final alerts = _collectAllAlerts();

    if (alerts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: BrandTokens.stitchOnlineFg.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 64,
                  color: BrandTokens.stitchOnlineFg,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Không có cảnh báo nào',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tất cả các hệ thống IGNIVO đang trong trạng thái an toàn, không có sự cố nào chưa xử lý.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? BrandTokens.darkTextSecondary
                      : BrandTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final sysName = alert['_systemName']?.toString() ?? 'Hệ thống';
        final id = alert['id'] ?? alert['incident_id'] ?? 0;
        final sev = (alert['severity']?.toString() ?? 'critical').toUpperCase();
        final status = alert['status']?.toString() ?? 'Đang xử lý';
        final camera = alert['camera_name']?.toString() ?? 'Camera';
        final time = alert['created_at']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            side: BorderSide(
              color: BrandTokens.criticalFg.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            onTap: () => _openIncidentDetail(alert),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BrandTokens.brandPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  BrandTokens.brandPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          sysName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: BrandTokens.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BrandTokens.criticalFg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sev,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '#$id',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Phát hiện sự cố cháy tại $camera',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      time.replaceAll('T', ' '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? BrandTokens.darkTextSecondary
                            : BrandTokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trạng thái: $status',
                        style: const TextStyle(
                          fontSize: 12,
                          color: BrandTokens.criticalFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openIncidentDetail(alert),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Xem chi tiết'),
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
      },
    );
  }

  Widget _buildMeTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<SystemRecord> systems,
  ) {
    final email =
        widget.authController?.currentUserEmail ?? 'Người dùng IGNIVO';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User Profile Header Card
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
                  backgroundColor: BrandTokens.brandPrimary,
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tài khoản Cloud • ${systems.length} hệ thống',
                        style: theme.textTheme.bodySmall?.copyWith(
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
        ),
        const SizedBox(height: 20),

        // Section: Chia sẻ & Thiết bị
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'QUẢN LÝ & CHIA SẺ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? BrandTokens.darkTextSecondary
                  : BrandTokens.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
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
                leading: const Icon(Icons.mail_outline_rounded,
                    color: BrandTokens.brandPrimary),
                title: const Text('Lời mời tham gia hệ thống',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Xem và chấp nhận lời mời từ chủ nhà khác',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _openInvitationsPage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.devices_rounded,
                    color: BrandTokens.brandPrimary),
                title: const Text('Hệ thống của tôi',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${systems.length} hệ thống đang liên kết',
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => setState(() => _currentTab = 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: Cài đặt ứng dụng
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'CÀI ĐẶT ỨNG DỤNG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? BrandTokens.darkTextSecondary
                  : BrandTokens.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
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
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('Âm chuông cảnh báo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Còi hú và rung khi có sự cố khẩn cấp',
                    style: TextStyle(fontSize: 12)),
                trailing: Switch(
                  value: true,
                  onChanged: (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Chuông cảnh báo luôn được bật để đảm bảo an toàn PCCC.')),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Giới thiệu IGNIVO',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Phiên bản 4.1.0 • Multi-System & Cloud Sharing',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
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

        // Section: Đăng xuất
        if (widget.authController != null)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
              side: BorderSide(
                color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Đăng xuất tài khoản Cloud',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Đăng xuất khỏi tài khoản trên thiết bị này',
                style: TextStyle(fontSize: 12),
              ),
              trailing:
                  const Icon(Icons.chevron_right, size: 20, color: Colors.red),
              onTap: _confirmSignOutAccount,
            ),
          ),
      ],
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
        onTap: () => _switchToSystem(system, openMonitoring: true),
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
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: system.role == 'OWNER'
                                ? (isDark
                                    ? BrandTokens.darkBrandTint
                                    : BrandTokens.brandTint)
                                : (isDark
                                    ? BrandTokens.darkSurfaceVariant
                                    : BrandTokens.background),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: system.role == 'OWNER'
                                  ? BrandTokens.brandPrimary.withValues(alpha: 0.3)
                                  : (isDark
                                      ? BrandTokens.darkBorder
                                      : BrandTokens.border),
                            ),
                          ),
                          child: Text(
                            system.roleDisplayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: system.role == 'OWNER'
                                  ? BrandTokens.brandPrimary
                                  : null,
                            ),
                          ),
                        ),
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isActive)
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _switchToSystem(system, openMonitoring: true),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Vào giám sát'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () =>
                          _switchToSystem(system, openMonitoring: false),
                      icon: const Icon(Icons.check_rounded, size: 16),
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
