import 'package:flutter/material.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_logo.dart';
import 'incident_page.dart';
import 'monitoring_controller.dart';
import 'monitor_widgets.dart';

class GuardHomePage extends StatelessWidget {
  const GuardHomePage({
    super.key,
    required this.sessionController,
    required this.monitoringController,
    this.onNavigateTab,
    this.onOpenIncident,
    this.onOpenLiveView,
    this.onOpenDiagnostics,
  });

  final SystemSessionController sessionController;
  final MonitoringController monitoringController;
  final void Function(int tabIndex)? onNavigateTab;
  final void Function(int incidentId)? onOpenIncident;
  final void Function(int cameraId)? onOpenLiveView;
  final VoidCallback? onOpenDiagnostics;

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Chưa cập nhật';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitoringController,
      builder: (context, _) {
        final theme = Theme.of(context);
        final status = monitoringController.status;
        final cameras = monitoringController.cameras;
        final incidents = monitoringController.incidents;
        final active = monitoringController.activeIncident;
        final isStale = monitoringController.stale;

        // Filter active incidents (status not resolved or false_alarm)
        final unclosedIncidents = incidents.where((inc) {
          final s = inc['status'];
          return s != 'resolved' && s != 'false_alarm';
        }).toList();

        return RefreshIndicator(
          onRefresh: monitoringController.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // 1. Header: Brand Logo & Location Name & Sync Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const IgnivoLogo.mark(size: 44),
                const SizedBox(width: BrandTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionController.systemName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isStale ? Icons.sync_problem : Icons.check_circle,
                            size: 14,
                            color: isStale ? BrandTokens.mediumFg : BrandTokens.normalFg,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isStale
                                  ? 'Dữ liệu chưa đồng bộ (${_formatTime(monitoringController.updated)})'
                                  : 'Đồng bộ lúc ${_formatTime(monitoringController.updated)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isStale ? BrandTokens.mediumFg : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onOpenDiagnostics != null)
                  IconButton(
                    icon: const Icon(Icons.monitor_heart_outlined),
                    tooltip: 'Chẩn đoán hệ thống',
                    onPressed: onOpenDiagnostics,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Alert Banner / Safe State
            if (unclosedIncidents.isNotEmpty || active != null) ...[
              _buildActiveIncidentBanner(context, active ?? unclosedIncidents.first, unclosedIncidents.length),
            ] else ...[
              _buildSafeStateBanner(context, isStale),
            ],
            const SizedBox(height: 20),

            // 3. Monitoring Readiness Section
            _buildReadinessCard(context, status, cameras),
            const SizedBox(height: 20),

            // 4. Quick Cameras Preview
            _buildQuickCamerasSection(context, cameras),
            const SizedBox(height: 20),

            // 5. Recent Activity Section
            _buildRecentActivitySection(context, incidents),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildActiveIncidentBanner(BuildContext context, Map<String, dynamic> inc, int totalActive) {
    final id = inc['id'] as int? ?? 0;
    final rawSeverity = inc['severity']?.toString();
    final severityText = (rawSeverity != null && rawSeverity.trim().isNotEmpty)
        ? rawSeverity.toUpperCase()
        : 'CHƯA XÁC ĐỊNH';
    final area = inc['area']?.toString() ?? 'Chưa xác định';
    final statusStr = AlertPresentationMapping.statusLabel(inc['status']?.toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusStyle = AlertPresentationMapping.statusStyle(severity: rawSeverity, isDark: isDark);
    final shouldPulse = AlertPresentationMapping.shouldPulse(
      incident: inc,
      stale: monitoringController.stale,
      disableAnimations: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );

    return PulsingAlertWrapper(
      active: shouldPulse,
      glowColor: statusStyle.border,
      child: Container(
        padding: const EdgeInsets.all(BrandTokens.space16),
        decoration: BoxDecoration(
          color: statusStyle.background,
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          border: Border.all(color: statusStyle.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: statusStyle.foreground, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SỰ CỐ CẦN CHÚ Ý (#$id)',
                    style: TextStyle(
                      color: statusStyle.foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusStyle.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
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
                color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
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
                    ),
                    onPressed: () => onOpenIncident?.call(id),
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: const Text('Xem bằng chứng & xử lý', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (totalActive > 1) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: statusStyle.foreground,
                      side: BorderSide(color: statusStyle.border),
                    ),
                    onPressed: () => onNavigateTab?.call(2),
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

  Widget _buildSafeStateBanner(BuildContext context, bool isStale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isStale
            ? Colors.amber.shade900.withValues(alpha: 0.15)
            : Colors.green.shade900.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStale ? Colors.amber.shade600 : Colors.green.shade600,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isStale ? Icons.info_outline : Icons.shield_outlined,
            color: isStale ? Colors.amber.shade700 : Colors.green.shade600,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStale
                      ? 'Dữ liệu giám sát cần đồng bộ lại'
                      : 'Chưa ghi nhận cảnh báo trong dữ liệu hiện có',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isStale
                      ? 'Hệ thống đang cố gắng kết nối lại với Pi để làm mới trạng thái.'
                      : 'Các camera và mô hình nhận diện AI đang trong trạng thái hoạt động chủ động.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessCard(BuildContext context, Map<String, dynamic>? status, List<Map<String, dynamic>> cameras) {
    final theme = Theme.of(context);
    final totalCameras = cameras.length;
    final onlineCameras = cameras.where((c) => (c['status'] as Map?)?['online'] == true).length;
    final callConfigured = status?['stringee_configured'] == true;
    final familyCount = status?['family_contacts'] as int? ?? 0;
    final fireDeptCount = status?['fire_dept_contacts'] as int? ?? 0;

    return GuardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mức sẵn sàng giám sát',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildReadinessItem(
                  context,
                  icon: Icons.videocam_outlined,
                  title: 'Camera giám sát',
                  subtitle: totalCameras > 0 ? '$onlineCameras/$totalCameras trực tuyến' : 'Chưa có camera',
                  isOk: totalCameras > 0 && onlineCameras == totalCameras,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReadinessItem(
                  context,
                  icon: Icons.phone_in_talk_outlined,
                  title: 'Gọi người liên hệ',
                  subtitle: callConfigured
                      ? '$familyCount người thân · $fireDeptCount PCCC'
                      : 'Chưa sẵn sàng gọi',
                  isOk: callConfigured && (familyCount + fireDeptCount > 0),
                ),
              ),
            ],
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
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: isOk ? Colors.green : Colors.orange),
              const Spacer(),
              Icon(
                isOk ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 16,
                color: isOk ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCamerasSection(BuildContext context, List<Map<String, dynamic>> cameras) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Xem nhanh Camera',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (cameras.isNotEmpty)
              TextButton(
                onPressed: () => onNavigateTab?.call(1),
                child: const Text('Tất cả camera'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (cameras.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: const Text('Chưa có camera nào được thiết lập trên Pi.'),
          ),
        ] else ...[
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cameras.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cam = cameras[index];
                final id = cam['id'] as int? ?? 0;
                final name = cam['name']?.toString() ?? 'Camera #$id';
                final area = cam['area']?.toString() ?? '';
                final isOnline = (cam['status'] as Map?)?['online'] == true;
                final aiResult = AiTelemetryEvaluator.evaluate(
                  camera: cam,
                  stale: monitoringController.stale,
                );

                return InkWell(
                  onTap: () => onOpenLiveView?.call(id),
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  child: Container(
                    width: 175,
                    padding: const EdgeInsets.all(BrandTokens.space12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              size: 18,
                              color: isOnline ? BrandTokens.normalFg : BrandTokens.staleFg,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isOnline ? BrandTokens.normalFg : BrandTokens.staleFg,
                                ),
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? BrandTokens.normalFg : BrandTokens.criticalFg,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (area.isNotEmpty)
                          Text(
                            area,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          aiResult.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: aiResult.isActive
                                ? BrandTokens.normalFg
                                : (aiResult.isError ? BrandTokens.criticalFg : BrandTokens.staleFg),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, List<Map<String, dynamic>> incidents) {
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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (incidents.isNotEmpty)
              TextButton(
                onPressed: () => onNavigateTab?.call(2),
                child: const Text('Lịch sử đầy đủ'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: const Text('Chưa có hoạt động nào được ghi nhận.'),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = recent[index];
              final id = item['id'] as int? ?? 0;
              final status = incidentStatusLabel(item['status']);
              final severity = item['severity']?.toString() ?? '';
              final area = item['area']?.toString() ?? 'Chưa xác định';
              final time = item['created_at']?.toString() ?? '';

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                tileColor: theme.cardColor,
                leading: CircleAvatar(
                  backgroundColor: severity == 'critical' || severity == 'high'
                      ? Colors.red.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.local_fire_department,
                    color: severity == 'critical' || severity == 'high'
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
                title: Text('Sự cố #$id — $area', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Trạng thái: $status · $time', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => onOpenIncident?.call(id),
              );
            },
          ),
        ],
      ],
    );
  }
}
