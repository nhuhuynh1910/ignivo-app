import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/camera_snapshot_loader.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/camera_preview_card.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/ignivo_sheet.dart';
import '../../widgets/recent_incident_tile.dart';
import '../../widgets/pulsing_status_dot.dart';
import '../../widgets/interactive_card.dart';
import 'monitoring_controller.dart';
import 'monitor_widgets.dart';

class GuardHomePage extends StatefulWidget {
  const GuardHomePage({
    super.key,
    required this.sessionController,
    required this.monitoringController,
    this.snapshotLoader,
    this.onNavigateTab,
    this.onOpenIncident,
    this.onOpenLiveView,
    this.onOpenDiagnostics,
  });

  final SystemSessionController sessionController;
  final MonitoringController monitoringController;
  final CameraSnapshotLoader? snapshotLoader;
  final void Function(int tabIndex)? onNavigateTab;
  final void Function(int incidentId)? onOpenIncident;
  final void Function(int cameraId)? onOpenLiveView;
  final VoidCallback? onOpenDiagnostics;

  @override
  State<GuardHomePage> createState() => _GuardHomePageState();
}

class _GuardHomePageState extends State<GuardHomePage> {
  late final CameraSnapshotLoader _snapshotLoader;
  bool _createdLoaderInternally = false;
  final Map<int, Uint8List> _snapshots = {};
  final Set<int> _attemptedSnapshots = {};
  final Set<int> _loadingSnapshots = {};

  @override
  void initState() {
    super.initState();
    if (widget.snapshotLoader != null) {
      _snapshotLoader = widget.snapshotLoader!;
    } else {
      _snapshotLoader = CameraSnapshotLoader(
        api: widget.monitoringController.api,
      );
      _createdLoaderInternally = true;
    }
  }

  @override
  void dispose() {
    if (_createdLoaderInternally) {
      _snapshotLoader.dispose();
    }
    super.dispose();
  }

  void _loadSnapshotForCamera(int id) {
    if (_attemptedSnapshots.contains(id) || _loadingSnapshots.contains(id)) return;
    _loadingSnapshots.add(id);
    _attemptedSnapshots.add(id);

    _snapshotLoader.loadSnapshot(id).then((result) {
      if (!mounted) return;
      setState(() {
        _loadingSnapshots.remove(id);
        if (result.isSuccess) {
          _snapshots[id] = result.bytes!;
        }
      });
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _loadingSnapshots.remove(id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.monitoringController,
      builder: (context, _) {
        final status = widget.monitoringController.status;
        final cameras = widget.monitoringController.cameras;
        final incidents = widget.monitoringController.incidents;
        final active = widget.monitoringController.activeIncident;
        final isStale = widget.monitoringController.stale;

        // Lọc các sự cố chưa kết thúc (status != resolved && status != false_alarm)
        final unclosedIncidents = incidents.where((inc) {
          final s = inc['status'];
          return s != 'resolved' && s != 'false_alarm';
        }).toList();

        final totalCameras = cameras.length;
        final onlineCameras = cameras
            .where((c) => (c['status'] as Map?)?['online'] == true)
            .length;

        final isAiActive = status?['vision']?['ready'] == true ||
            status?['vision']?['active'] == true;
        final vision = status?['vision'] as Map?;
        final aiFps = (vision?['total_ai_fps'] ??
                status?['total_ai_fps'] ??
                status?['ai_fps'] as num?)
            ?.toDouble() ??
            0.0;

        return IgnivoPageBody(
          header: IgnivoPageHeader(
            title: 'Trang chủ',
            systemName: widget.sessionController.systemName,
            showSync: true,
            updatedAt: widget.monitoringController.updated,
            stale: isStale,
            onTapAvatar: widget.onNavigateTab != null
                ? () => widget.onNavigateTab!(3)
                : null,
            onTapSystem: () {
              showIgnivoSystemSheet(
                context: context,
                systemName: widget.sessionController.systemName,
                address: widget.sessionController.profile.guardUrl,
                isConnected: !isStale,
                cameraCount: totalCameras,
                onDiagnostics: widget.onOpenDiagnostics,
                onChangeConnection: () => widget.sessionController.disconnect(),
              );
            },
            action: widget.onOpenDiagnostics == null
                ? null
                : IgnivoHeaderAction(
                    icon: Icons.monitor_heart_outlined,
                    tooltip: 'Chẩn đoán hệ thống',
                    onPressed: widget.onOpenDiagnostics,
                  ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;

              return RefreshIndicator(
                onRefresh: () async {
                  _snapshotLoader.clearCache();
                  _snapshots.clear();
                  _attemptedSnapshots.clear();
                  _loadingSnapshots.clear();
                  await widget.monitoringController.refresh();
                },
                child: isDesktop
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1380),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Desktop KPI Metric Summary Row
                                _buildDesktopKpiRow(
                                  context,
                                  isAiActive: isAiActive,
                                  aiFps: aiFps,
                                  totalCameras: totalCameras,
                                  onlineCameras: onlineCameras,
                                  unclosedIncidents: unclosedIncidents,
                                  isStale: isStale,
                                  callConfigured:
                                      status?['stringee_configured'] == true,
                                ),
                                const SizedBox(height: 16),

                                // 2. Smart Status Chips Row (Apple Home style)
                                _buildStatusChipsBar(
                                  context,
                                  isStale: isStale,
                                  isAiActive: isAiActive,
                                  aiFps: aiFps,
                                  totalCameras: totalCameras,
                                  onlineCameras: onlineCameras,
                                  unclosedIncidents: unclosedIncidents,
                                  callConfigured:
                                      status?['stringee_configured'] == true,
                                  isDesktop: true,
                                ),
                                const SizedBox(height: 20),

                                // 3. Bento 2-Column Dashboard Layout
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left / Main Column (flex: 62) - Tường Camera ở ngay trên cùng
                                    Expanded(
                                      flex: 62,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildQuickCamerasSection(
                                              context, cameras,
                                              isGrid: true),
                                          const SizedBox(height: 20),
                                          _buildReadinessCard(
                                            context,
                                            status,
                                            cameras,
                                            isAiActive: isAiActive,
                                            aiFps: aiFps,
                                            isStale: isStale,
                                            cpuTemp: status?['cpu_temp_c'],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // Right / Sidebar Column (flex: 38)
                                    Expanded(
                                      flex: 38,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (unclosedIncidents.isNotEmpty ||
                                              active != null) ...[
                                            _buildActiveIncidentBanner(
                                              context,
                                              active ??
                                                  unclosedIncidents.first,
                                              unclosedIncidents.length,
                                            ),
                                            const SizedBox(height: 18),
                                          ],
                                          _buildRecentActivitySection(
                                              context, incidents),
                                          const SizedBox(height: 20),
                                          _buildDesktopQuickActions(context),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Priority Alert Banner (khi có sự cố cần chú ý)
                                if (unclosedIncidents.isNotEmpty ||
                                    active != null) ...[
                                  _buildActiveIncidentBanner(
                                    context,
                                    active ?? unclosedIncidents.first,
                                    unclosedIncidents.length,
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // 2. Smart Status Chips Row (Apple Home style) - Siêu tinh gọn ~36px
                                _buildStatusChipsBar(
                                  context,
                                  isStale: isStale,
                                  isAiActive: isAiActive,
                                  aiFps: aiFps,
                                  totalCameras: totalCameras,
                                  onlineCameras: onlineCameras,
                                  unclosedIncidents: unclosedIncidents,
                                  callConfigured:
                                      status?['stringee_configured'] == true,
                                  isDesktop: false,
                                ),
                                const SizedBox(height: 18),

                                // 3. Xem nhanh Camera (Quick Cameras Preview) - Đập ngay vào mắt!
                                _buildQuickCamerasSection(context, cameras),
                                const SizedBox(height: 20),

                                // 4. Hoạt động gần đây (Recent Incidents) - Đặt ngay dưới Camera để quét nhanh
                                _buildRecentActivitySection(context, incidents),
                                const SizedBox(height: 20),

                                // 5. Mức sẵn sàng giám sát & Thiết bị (Monitoring Readiness)
                                _buildReadinessCard(
                                  context,
                                  status,
                                  cameras,
                                  isAiActive: isAiActive,
                                  aiFps: aiFps,
                                  isStale: isStale,
                                  cpuTemp: status?['cpu_temp_c'],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveIncidentBanner(
    BuildContext context,
    Map<String, dynamic> inc,
    int totalActive,
  ) {
    final id = inc['id'] as int? ?? 0;
    final rawSeverity = inc['severity']?.toString();
    final severityText = (rawSeverity != null && rawSeverity.trim().isNotEmpty)
        ? rawSeverity.toUpperCase()
        : 'CHƯA XÁC ĐỊNH';
    final area = inc['area']?.toString() ?? 'Chưa xác định';
    final statusStr = AlertPresentationMapping.statusLabel(
      inc['status']?.toString(),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusStyle = AlertPresentationMapping.statusStyle(
      severity: rawSeverity,
      isDark: isDark,
    );
    final shouldPulse = AlertPresentationMapping.shouldPulse(
      incident: inc,
      stale: widget.monitoringController.stale,
      disableAnimations:
          MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );

    final statusRaw = inc['status']?.toString().toLowerCase().trim();
    final isAck = statusRaw == 'ack' ||
        statusRaw == 'acknowledged' ||
        statusRaw == 'handling' ||
        inc['ack'] == true ||
        inc['is_acknowledged'] == true;
    final kickerText = isAck
        ? 'SỰ CỐ ĐANG ĐƯỢC XỬ LÝ (#$id)'
        : 'SỰ CỐ CẦN CHÚ Ý (#$id)';

    return PulsingAlertWrapper(
      active: shouldPulse,
      glowColor: statusStyle.border,
      child: Container(
        padding: const EdgeInsets.all(BrandTokens.space16),
        decoration: BoxDecoration(
          color: statusStyle.background,
          borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
          border: Border.all(color: statusStyle.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: statusStyle.border.withValues(alpha: isDark ? 0.3 : 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAck
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: statusStyle.foreground,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kickerText,
                    style: TextStyle(
                      color: statusStyle.foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusStyle.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(
                      BrandTokens.badgeRadius,
                    ),
                  ),
                  child: Text(
                    severityText,
                    style: TextStyle(
                      color: statusStyle.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Khu vực: $area · Trạng thái: $statusStr',
              style: TextStyle(
                color: isDark
                    ? BrandTokens.darkTextPrimary
                    : BrandTokens.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusStyle.foreground,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => widget.onOpenIncident?.call(id),
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: const Text(
                      'Xem bằng chứng & xử lý',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (totalActive > 1) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: statusStyle.foreground,
                      side: BorderSide(color: statusStyle.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => widget.onNavigateTab?.call(2),
                    child: Text('Tất cả ($totalActive)'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Command Center Helpers
  // ---------------------------------------------------------------------------

  Widget _buildDesktopKpiRow(
    BuildContext context, {
    required bool isAiActive,
    required double aiFps,
    required int totalCameras,
    required int onlineCameras,
    required List<Map<String, dynamic>> unclosedIncidents,
    required bool isStale,
    required bool callConfigured,
  }) {
    return Row(
      children: [
        // KPI 1: AI Vision / Hailo-8
        Expanded(
          child: _buildKpiCard(
            context,
            title: 'TRẠNG THÁI AI GIÁM SÁT',
            value: isAiActive
                ? (aiFps > 0 ? 'Đang bảo vệ' : 'Sẵn sàng')
                : 'Chưa kích hoạt',
            subtitle: isAiActive
                ? (aiFps > 0
                    ? 'Xử lý hình ảnh: ${aiFps.toStringAsFixed(1)} FPS'
                    : 'Nhận diện thị giác chủ động')
                : 'Cần kiểm tra service',
            icon: Icons.psychology_rounded,
            color:
                isAiActive ? BrandTokens.stitchSafe : BrandTokens.stitchWarning,
            isPulsing: isAiActive,
            onTap: widget.onOpenDiagnostics,
          ),
        ),
        const SizedBox(width: 14),
        // KPI 2: Giám sát Camera
        Expanded(
          child: _buildKpiCard(
            context,
            title: 'CAMERA TRỰC TUYẾN',
            value: totalCameras > 0
                ? '$onlineCameras/$totalCameras Online'
                : '0 Camera',
            subtitle: totalCameras > 0 && onlineCameras == totalCameras
                ? 'Tất cả kết nối ổn định'
                : 'Có camera ngắt kết nối',
            icon: Icons.videocam_rounded,
            color: (totalCameras > 0 && onlineCameras == totalCameras)
                ? BrandTokens.stitchSafe
                : (onlineCameras > 0
                    ? BrandTokens.stitchWarning
                    : BrandTokens.stitchCritical),
            onTap: () => widget.onNavigateTab?.call(1),
          ),
        ),
        const SizedBox(width: 14),
        // KPI 3: Tình trạng an toàn / sự cố
        Expanded(
          child: _buildKpiCard(
            context,
            title: 'CẢNH BÁO / SỰ CỐ',
            value: unclosedIncidents.isEmpty
                ? '0 Sự cố'
                : '${unclosedIncidents.length} Cần xử lý',
            subtitle: unclosedIncidents.isEmpty
                ? 'Khu vực đang an toàn'
                : 'Yêu cầu kiểm tra ngay',
            icon: Icons.warning_amber_rounded,
            color: unclosedIncidents.isEmpty
                ? BrandTokens.stitchSafe
                : BrandTokens.stitchCritical,
            isPulsing: unclosedIncidents.isNotEmpty,
            onTap: () => widget.onNavigateTab?.call(2),
          ),
        ),
        const SizedBox(width: 14),
        // KPI 4: Trạng thái còi / liên hệ PCCC
        Expanded(
          child: _buildKpiCard(
            context,
            title: 'LIÊN HỆ KHẨN CẤP',
            value: callConfigured ? 'Sẵn sàng gọi' : 'Chưa thiết lập',
            subtitle: isStale ? 'Đang kết nối lại Pi' : 'Stringee & SOS active',
            icon: Icons.phone_in_talk_rounded,
            color: callConfigured
                ? BrandTokens.stitchSafe
                : BrandTokens.stitchWarning,
            onTap: () => widget.onNavigateTab?.call(3),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isPulsing = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InteractiveCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPulsing) ...[
                const SizedBox(width: 4),
                PulsingStatusDot(color: color, size: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopQuickActions(BuildContext context) {
    final theme = Theme.of(context);

    return InteractiveCard(
      borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
      padding: const EdgeInsets.all(BrandTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 18, color: BrandTokens.brandPrimary),
              const SizedBox(width: 8),
              Text(
                'Lệnh thao tác nhanh',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickActionBtn(
            context,
            icon: Icons.grid_view_rounded,
            label: 'Mở tường Camera toàn cảnh',
            onTap: () => widget.onNavigateTab?.call(1),
          ),
          const SizedBox(height: 8),
          _buildQuickActionBtn(
            context,
            icon: Icons.history_edu_rounded,
            label: 'Lịch sử nhận diện & sự cố',
            onTap: () => widget.onNavigateTab?.call(2),
          ),
          const SizedBox(height: 8),
          _buildQuickActionBtn(
            context,
            icon: Icons.monitor_heart_outlined,
            label: 'Kiểm tra phần cứng & NPU',
            onTap: widget.onOpenDiagnostics,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Core Page Sections
  // ---------------------------------------------------------------------------

  Widget _buildStatusChipsBar(
    BuildContext context, {
    required bool isStale,
    required bool isAiActive,
    required double aiFps,
    required int totalCameras,
    required int onlineCameras,
    required List<Map<String, dynamic>> unclosedIncidents,
    required bool callConfigured,
    bool isDesktop = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasIncidents = unclosedIncidents.isNotEmpty;
    final safeColor = hasIncidents
        ? BrandTokens.stitchCritical
        : (isStale ? Colors.amber.shade700 : const Color(0xFF007A3D));

    final safeBg = hasIncidents
        ? BrandTokens.stitchCritical.withValues(alpha: isDark ? 0.22 : 0.10)
        : (isStale
            ? Colors.amber.shade900.withValues(alpha: isDark ? 0.22 : 0.10)
            : const Color(0xFF007A3D).withValues(alpha: isDark ? 0.20 : 0.10));

    final safeBorder = safeColor.withValues(alpha: isDark ? 0.45 : 0.35);

    final safeText = hasIncidents
        ? '${unclosedIncidents.length} sự cố cần chú ý'
        : (isStale
            ? 'Dữ liệu giám sát cần đồng bộ lại'
            : 'Chưa ghi nhận cảnh báo trong dữ liệu hiện có');

    final chips = <Widget>[
      // 1. Safety Status Chip (Primary Calibrated Highlight)
      _buildStatusPill(
        context,
        icon: hasIncidents
            ? Icons.warning_amber_rounded
            : (isStale ? Icons.sync_problem_rounded : Icons.shield_outlined),
        label: safeText,
        color: safeColor,
        backgroundColor: safeBg,
        borderColor: safeBorder,
        hasPulseDot: true,
        onTap: () {
          if (hasIncidents) {
            widget.onNavigateTab?.call(2);
          } else {
            widget.onOpenDiagnostics?.call();
          }
        },
      ),
      const SizedBox(width: 8),

      // 2. Edge Hardware Box Chip
      _buildStatusPill(
        context,
        icon: Icons.developer_board_rounded,
        label: isStale ? 'Edge Box: Đang kết nối' : 'Edge Box: Online',
        color: isStale ? Colors.amber.shade700 : BrandTokens.stitchSafe,
        onTap: widget.onOpenDiagnostics,
      ),
      const SizedBox(width: 8),

      // 3. AI Monitoring Chip
      _buildStatusPill(
        context,
        icon: Icons.psychology_outlined,
        label: isAiActive
            ? (aiFps > 0
                ? 'AI: Đang giám sát (${aiFps.toStringAsFixed(1)} FPS)'
                : 'AI: Sẵn sàng')
            : 'AI: Tắt',
        color: isAiActive ? BrandTokens.stitchSafe : BrandTokens.stitchWarning,
        onTap: widget.onOpenDiagnostics,
      ),
      const SizedBox(width: 8),

      // 4. Cameras Online Chip
      _buildStatusPill(
        context,
        icon: Icons.videocam_outlined,
        label: totalCameras > 0
            ? '$onlineCameras/$totalCameras Camera online'
            : 'Chưa có camera',
        color: (totalCameras > 0 && onlineCameras == totalCameras)
            ? BrandTokens.stitchSafe
            : (onlineCameras > 0
                ? BrandTokens.stitchWarning
                : theme.textTheme.bodySmall?.color ?? Colors.grey),
        onTap: () => widget.onNavigateTab?.call(1),
      ),
      const SizedBox(width: 8),

      // 5. Emergency Hotline / SOS Chip
      _buildStatusPill(
        context,
        icon: Icons.phone_in_talk_outlined,
        label: callConfigured ? 'SOS: Sẵn sàng' : 'SOS: Chưa cấu hình',
        color: callConfigured
            ? BrandTokens.stitchSafe
            : BrandTokens.stitchWarning,
        onTap: () => widget.onNavigateTab?.call(3),
      ),
    ];

    if (isDesktop) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: chips,
      ),
    );
  }

  Widget _buildStatusPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    bool hasPulseDot = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : theme.cardColor);

    final border = borderColor ?? theme.dividerColor.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 0.8),
            boxShadow: BrandTokens.softShadow(isDark: isDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? BrandTokens.darkTextPrimary
                      : BrandTokens.textPrimary,
                ),
              ),
              if (hasPulseDot) ...[
                const SizedBox(width: 6),
                PulsingStatusDot(color: color, size: 6, pulseSize: 13),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadinessCard(
    BuildContext context,
    Map<String, dynamic>? status,
    List<Map<String, dynamic>> cameras, {
    bool isAiActive = false,
    double aiFps = 0.0,
    bool isStale = false,
    dynamic cpuTemp,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalCameras = cameras.length;
    final onlineCameras = cameras
        .where((c) => (c['status'] as Map?)?['online'] == true)
        .length;
    final callConfigured = status?['stringee_configured'] == true;
    final familyCount = status?['family_contacts'] as int? ?? 0;
    final fireDeptCount = status?['fire_dept_contacts'] as int? ?? 0;

    final isCamerasOk = totalCameras > 0 && onlineCameras == totalCameras;
    final isAiOk = isAiActive;
    final isEdgeOk = !isStale;
    final isSosOk = callConfigured && (familyCount + fireDeptCount > 0);

    int readyCount = 0;
    if (isCamerasOk) readyCount++;
    if (isAiOk) readyCount++;
    if (isEdgeOk) readyCount++;
    if (isSosOk) readyCount++;

    final isAllReady = readyCount == 4;

    return Container(
      padding: const EdgeInsets.all(BrandTokens.space16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Đề xuất C: Header với Nhịp tim hệ thống và Huy hiệu sức khỏe tổng thể
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mức sẵn sàng giám sát',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulsingStatusDot(
                          color: isStale
                              ? Colors.amber.shade800
                              : BrandTokens.stitchSafe,
                          size: 6,
                          pulseSize: 12,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isStale
                                ? 'Mất kết nối đồng bộ'
                                : 'Đang quét an toàn thời gian thực',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isStale
                                  ? Colors.amber.shade800
                                  : (isDark
                                      ? BrandTokens.darkTextSecondary
                                      : BrandTokens.textSecondary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isAllReady
                      ? BrandTokens.stitchSafe.withValues(alpha: isDark ? 0.2 : 0.1)
                      : (isStale
                          ? Colors.amber.shade900.withValues(alpha: isDark ? 0.2 : 0.1)
                          : BrandTokens.stitchWarning.withValues(alpha: isDark ? 0.2 : 0.1)),
                  borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
                  border: Border.all(
                    color: isAllReady
                        ? BrandTokens.stitchSafe.withValues(alpha: 0.4)
                        : (isStale
                            ? Colors.amber.shade800.withValues(alpha: 0.4)
                            : BrandTokens.stitchWarning.withValues(alpha: 0.4)),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAllReady
                          ? Icons.verified_user_rounded
                          : (isStale ? Icons.sync_problem_rounded : Icons.info_outline),
                      size: 13,
                      color: isAllReady
                          ? BrandTokens.stitchSafe
                          : (isStale ? Colors.amber.shade800 : BrandTokens.stitchWarning),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAllReady
                          ? '100% Sẵn sàng'
                          : (isStale ? 'Cần đồng bộ' : '$readyCount/4 Sẵn sàng'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isAllReady
                            ? BrandTokens.stitchSafe
                            : (isStale ? Colors.amber.shade800 : BrandTokens.stitchWarning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Đề xuất A & B: Lưới 4 trụ cột an toàn 2x2 với tương tác 1 chạm
          Row(
            children: [
              Expanded(
                child: _buildReadinessItem(
                  context,
                  icon: Icons.videocam_outlined,
                  title: 'Camera giám sát',
                  subtitle: totalCameras > 0
                      ? '$onlineCameras/$totalCameras trực tuyến'
                      : 'Chưa có camera',
                  isOk: isCamerasOk,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildReadinessItem(
                  context,
                  icon: Icons.psychology_outlined,
                  title: 'AI Thị giác & Hailo',
                  subtitle: isAiActive
                      ? (aiFps > 0
                          ? '${aiFps.toStringAsFixed(1)} FPS · Đang bảo vệ'
                          : 'Sẵn sàng nhận diện')
                      : 'Chưa kích hoạt',
                  isOk: isAiOk,
                  onTap: widget.onOpenDiagnostics,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildReadinessItem(
                  context,
                  icon: Icons.developer_board_rounded,
                  title: 'Thiết bị biên (Pi)',
                  subtitle: isStale
                      ? 'Đang kết nối lại...'
                      : (cpuTemp != null ? 'Trực tuyến · $cpuTemp°C' : 'Trực tuyến'),
                  isOk: isEdgeOk,
                  onTap: widget.onOpenDiagnostics,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildReadinessItem(
                  context,
                  icon: Icons.phone_in_talk_outlined,
                  title: 'Gọi người liên hệ',
                  subtitle: callConfigured
                      ? '$familyCount người thân · $fireDeptCount PCCC'
                      : 'Chưa sẵn sàng gọi',
                  isOk: isSosOk,
                  onTap: () => widget.onNavigateTab?.call(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('hardware_telemetry_expansion_tile'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              title: Text(
                'Thông số phần cứng & AI Edge',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(
                      BrandTokens.stitchSmallCardRadius,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Bộ tăng tốc Hailo AI NPU',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            aiFps > 0
                                ? '${aiFps.toStringAsFixed(1)} FPS'
                                : (isAiActive ? 'Sẵn sàng' : 'Không khả dụng'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Thiết bị biên (Edge Box)',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isStale
                                ? 'Đang kết nối lại'
                                : (cpuTemp != null ? 'Trực tuyến · $cpuTemp°C' : 'Trực tuyến'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isStale
                                  ? BrandTokens.stitchWarning
                                  : BrandTokens.stitchSafe,
                            ),
                          ),
                        ],
                      ),
                      if (widget.onOpenDiagnostics != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: widget.onOpenDiagnostics,
                            icon: const Icon(
                              Icons.monitor_heart_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'Xem chẩn đoán chi tiết',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isOk,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
            border: Border.all(
              color: isOk
                  ? theme.dividerColor.withValues(alpha: 0.10)
                  : BrandTokens.stitchWarning.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: (isOk ? BrandTokens.stitchSafe : BrandTokens.stitchWarning)
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isOk ? BrandTokens.stitchSafe : BrandTokens.stitchWarning,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isOk ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 14,
                    color: isOk ? BrandTokens.stitchSafe : BrandTokens.stitchWarning,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCardItem(Map<String, dynamic> cam) {
    final id = cam['id'] as int? ?? 0;
    final name = cam['name']?.toString() ?? 'Camera #$id';
    final area = cam['area']?.toString() ?? 'Chưa xác định';
    final isOnline = (cam['status'] as Map?)?['online'] as bool?;
    final detectEnabled = cam['detect_enabled'] != false;
    final fps = (cam['ai_fps'] is num)
        ? (cam['ai_fps'] as num).toDouble()
        : 8.0;

    if (!_attemptedSnapshots.contains(id) &&
        !_loadingSnapshots.contains(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSnapshotForCamera(id);
      });
    }

    return CameraPreviewCard(
      name: name,
      area: area,
      isOnline: isOnline,
      aiEnabled: detectEnabled,
      aiStatusText: detectEnabled ? 'AI nhận diện: BẬT' : 'AI: TẮT',
      aiFps: fps,
      snapshotBytes: _snapshots[id],
      isSnapshotLoading: _loadingSnapshots.contains(id),
      onTap: () => widget.onOpenLiveView?.call(id),
    );
  }

  Widget _buildQuickCamerasSection(
    BuildContext context,
    List<Map<String, dynamic>> cameras, {
    bool isGrid = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Xem nhanh Camera',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cameras.isNotEmpty)
              TextButton(
                onPressed: () => widget.onNavigateTab?.call(1),
                child: const Text('Tất cả camera'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (cameras.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
              boxShadow: BrandTokens.softShadow(
                  isDark: theme.brightness == Brightness.dark),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  size: 38,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chưa có camera nào được thiết lập trên Pi.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ] else if (isGrid && cameras.length >= 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCameraCardItem(cameras[0])),
              const SizedBox(width: 14),
              Expanded(child: _buildCameraCardItem(cameras[1])),
            ],
          ),
          if (cameras.length > 2) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => widget.onNavigateTab?.call(1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Xem thêm ${cameras.length - 2} camera khác'),
              ),
            ),
          ],
        ] else ...[
          ...cameras.take(2).map((cam) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCameraCardItem(cam),
            );
          }),
          if (cameras.length > 2)
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => widget.onNavigateTab?.call(1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Xem thêm ${cameras.length - 2} camera khác'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    List<Map<String, dynamic>> incidents,
  ) {
    final theme = Theme.of(context);
    final recent = incidents.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hoạt động gần đây',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (incidents.isNotEmpty)
              TextButton(
                onPressed: () => widget.onNavigateTab?.call(2),
                child: const Text('Lịch sử đầy đủ'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 38,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chưa có hoạt động nào được ghi nhận.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = recent[index];
              final id = item['id'] as int? ?? 0;
              final severity = item['severity']?.toString();
              final area = item['area']?.toString() ?? 'Chưa xác định';
              final time = item['created_at']?.toString() ?? '';
              final status = item['status']?.toString();
              final title = IncidentPresentationHelper.formatIncidentTitle(item);
              final timeFormatted =
                  IncidentPresentationHelper.formatTimestamp(time);

              return RecentIncidentTile(
                id: id,
                title: title,
                area: area,
                timeStr: timeFormatted.isNotEmpty ? timeFormatted : 'Vừa xong',
                severity: severity,
                status: status,
                onTap: () => widget.onOpenIncident?.call(id),
              );
            },
          ),
        ],
      ],
    );
  }
}
