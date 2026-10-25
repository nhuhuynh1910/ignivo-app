import 'package:flutter/material.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/interactive_card.dart';
import '../../widgets/recent_incident_tile.dart';
import '../fireguard/incident_page.dart';
import '../fireguard/monitoring_controller.dart';

class GuardActivityPage extends StatefulWidget {
  const GuardActivityPage({
    super.key,
    required this.monitoringController,
    this.sessionController,
    this.onOpenIncident,
  });

  final MonitoringController monitoringController;
  final SystemSessionController? sessionController;
  final void Function(int incidentId)? onOpenIncident;

  @override
  State<GuardActivityPage> createState() => _GuardActivityPageState();
}

class _GuardActivityPageState extends State<GuardActivityPage> {
  // 0: Tất cả, 1: Cần chú ý, 2: Đang xử lý, 3: Đã kết thúc, 4: Mô phỏng
  int _filterIndex = 0;

  void _navigateToDetail(BuildContext context, int incidentId) {
    if (widget.onOpenIncident != null) {
      widget.onOpenIncident!(incidentId);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FireguardIncidentPage(
            incidentId: incidentId,
            api: widget.monitoringController.api,
            realtime: widget.monitoringController.realtime,
            coordinator: widget.monitoringController.coordinator,
            controller: widget.monitoringController,
          ),
        ),
      );
    }
  }

  bool _matchesFilter(Map<String, dynamic> inc) {
    final status = inc['status']?.toString() ?? '';
    final trigger = inc['trigger_type']?.toString().toLowerCase() ?? '';
    final isSim = inc['is_simulation'] == true || trigger == 'simulation';

    switch (_filterIndex) {
      case 1:
        return ['analyzing', 'notifying', 'notified', 'ai_dismissed']
            .contains(status);
      case 2:
        return status == 'acknowledged';
      case 3:
        return ['resolved', 'false_alarm'].contains(status);
      case 4:
        return isSim;
      case 0:
      default:
        return true;
    }
  }

  String _formatCreatedAt(String raw) {
    if (raw.trim().isEmpty) return 'Chưa có thời gian';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} · '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.monitoringController,
      builder: (context, _) {
        final allIncidents = widget.monitoringController.incidents;
        final filtered = allIncidents.where(_matchesFilter).toList();

        final userName = widget.sessionController?.fullName ?? 'Quản trị viên';
        final initials = userName
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join('')
            .toUpperCase();

        final urgentCount = allIncidents
            .where((i) =>
            ['analyzing', 'notifying', 'notified', 'ai_dismissed']
                .contains(i['status']))
            .length;
        final ackCount = allIncidents
            .where((i) => i['status'] == 'acknowledged')
            .length;
        final resolvedCount = allIncidents
            .where((i) => ['resolved', 'false_alarm'].contains(i['status']))
            .length;

        return IgnivoPageBody(
          header: IgnivoPageHeader(
            title: 'Cảnh báo',
            systemName: widget.sessionController?.systemName ?? 'IGNIVO',
            avatarInitials: initials.isNotEmpty ? initials : 'MA',
            showSync: true,
            updatedAt: widget.monitoringController.updated,
            stale: widget.monitoringController.stale,
            action: IgnivoHeaderAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Làm mới hoạt động',
              onPressed: widget.monitoringController.refresh,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;

              return RefreshIndicator(
                onRefresh: widget.monitoringController.refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 24 : 16,
                    isDesktop ? 20 : 16,
                    isDesktop ? 24 : 16,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1380),
                      child: isDesktop
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildActivityKpiCard(
                                  context: context,
                                  title: 'TỔNG SỐ SỰ CỐ',
                                  value: '${allIncidents.length}',
                                  subtitle: 'Lịch sử đã ghi nhận',
                                  icon: Icons.history_rounded,
                                  color: BrandTokens.brandAccent,
                                  onTap: () => setState(() => _filterIndex = 0),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildActivityKpiCard(
                                  context: context,
                                  title: 'CẦN CHÚ Ý',
                                  value: '$urgentCount',
                                  subtitle: 'Cần kiểm tra',
                                  icon: Icons.warning_amber_rounded,
                                  color: BrandTokens.stitchCritical,
                                  onTap: () => setState(() => _filterIndex = 1),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildActivityKpiCard(
                                  context: context,
                                  title: 'ĐANG XỬ LÝ',
                                  value: '$ackCount',
                                  subtitle: 'Đã tiếp nhận',
                                  icon: Icons.engineering_rounded,
                                  color: BrandTokens.stitchWarning,
                                  onTap: () => setState(() => _filterIndex = 2),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildActivityKpiCard(
                                  context: context,
                                  title: 'ĐÃ KẾT THÚC',
                                  value: '$resolvedCount',
                                  subtitle: 'Đã đóng sự cố',
                                  icon: Icons.check_circle_rounded,
                                  color: BrandTokens.stitchSafe,
                                  onTap: () => setState(() => _filterIndex = 3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 65,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildListHeading(filtered.length, isDark),
                                    const SizedBox(height: 10),
                                    _buildFilterBar(allIncidents),
                                    const SizedBox(height: 14),
                                    _buildIncidentListView(
                                      context, filtered, allIncidents,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 35,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildOverviewInfoCard(
                                      context, isDark, urgentCount, ackCount,
                                    ),
                                    const SizedBox(height: 18),
                                    _buildProcedureCard(context, isDark),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMobileSummary(
                            allIncidents.length,
                            urgentCount,
                            ackCount,
                            resolvedCount,
                          ),
                          const SizedBox(height: 24),
                          _buildListHeading(filtered.length, isDark),
                          const SizedBox(height: 10),
                          _buildFilterBar(allIncidents),
                          const SizedBox(height: 14),
                          _buildIncidentListView(
                            context, filtered, allIncidents,
                          ),
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

  Widget _buildMobileSummary(
      int total,
      int urgent,
      int acknowledged,
      int resolved,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: BrandTokens.primaryGradient,
        borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
        boxShadow: BrandTokens.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TỔNG QUAN SỰ CỐ',
                      style: TextStyle(
                        color: Color(0xFFDCE5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sự cố đã ghi nhận',
                      style: TextStyle(color: Color(0xFFE5EBFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 25),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.19), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryCount('$urgent', 'Cần chú ý', const Color(0xFFFFC5CE)),
              _summaryCount('$acknowledged', 'Đang xử lý', const Color(0xFFFFE0A3)),
              _summaryCount('$resolved', 'Đã kết thúc', const Color(0xFFABF4D5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCount(String value, String label, Color textColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeading(int count, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Nhật ký sự cố',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy,
            ),
          ),
        ),
        Text(
          '$count bản ghi',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? BrandTokens.darkTextSecondary
                : BrandTokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InteractiveCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.19 : 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 27,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<Map<String, dynamic>> allIncidents) {
    final urgent = allIncidents.where((i) =>
        ['analyzing', 'notifying', 'notified', 'ai_dismissed']
            .contains(i['status'])).length;
    final acknowledged = allIncidents
        .where((i) => i['status'] == 'acknowledged').length;
    final finished = allIncidents.where((i) =>
        ['resolved', 'false_alarm'].contains(i['status'])).length;
    final simulations = allIncidents.where((i) =>
    i['is_simulation'] == true ||
        i['trigger_type']?.toString().toLowerCase() == 'simulation').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(0, 'Tất cả', count: allIncidents.length),
          const SizedBox(width: 8),
          _buildFilterChip(1, 'Cần chú ý', count: urgent, highlight: true),
          const SizedBox(width: 8),
          _buildFilterChip(2, 'Đang xử lý', count: acknowledged),
          const SizedBox(width: 8),
          _buildFilterChip(3, 'Đã kết thúc', count: finished),
          const SizedBox(width: 8),
          _buildFilterChip(4, 'Mô phỏng', count: simulations),
        ],
      ),
    );
  }

  Widget _buildIncidentListView(
      BuildContext context,
      List<Map<String, dynamic>> filtered,
      List<Map<String, dynamic>> allIncidents,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
          border: Border.all(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 42,
              color: isDark
                  ? BrandTokens.darkTextTertiary
                  : BrandTokens.brandAccent,
            ),
            const SizedBox(height: 12),
            Text(
              allIncidents.isEmpty
                  ? 'Chưa ghi nhận sự cố nào'
                  : 'Không có sự cố trong bộ lọc này',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              allIncidents.isEmpty
                  ? 'Hệ thống FireGuard ghi nhận tối đa 50 sự cố gần nhất.'
                  : 'Chọn bộ lọc khác để xem các bản ghi liên quan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final inc = filtered[index];
        final id = inc['id'] as int? ?? 0;
        final rawArea = inc['area']?.toString().trim() ?? '';
        final area = rawArea.isNotEmpty ? rawArea : 'Chưa xác định';
        final status = inc['status']?.toString();
        final severity = inc['severity']?.toString();
        final createdAt = inc['created_at']?.toString() ?? '';
        final isSim = inc['is_simulation'] == true ||
            inc['trigger_type']?.toString().toLowerCase() == 'simulation';

        return RecentIncidentTile(
          id: id,
          title: 'Sự cố #$id',
          area: area,
          timeStr: _formatCreatedAt(createdAt),
          severity: severity,
          status: status,
          triggerType: inc['trigger_type']?.toString(),
          isSimulation: isSim,
          onTap: () => _navigateToDetail(context, id),
        );
      },
    );
  }

  Widget _buildOverviewInfoCard(
      BuildContext context,
      bool isDark,
      int urgentCount,
      int ackCount,
      ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded,
                  size: 20,
                  color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Tình trạng giám sát',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            urgentCount > 0
                ? 'Có $urgentCount sự cố cần kiểm tra ngay.'
                : (ackCount > 0
                ? 'Không có sự cố cần chú ý mới; $ackCount sự cố đang xử lý.'
                : 'Không có sự cố trong nhóm cần chú ý hoặc đang xử lý.'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: urgentCount > 0
                  ? BrandTokens.stitchCritical
                  : (ackCount > 0
                  ? BrandTokens.stitchWarning
                  : (isDark
                  ? BrandTokens.stitchDarkOnlineFg
                  : BrandTokens.stitchOnlineFg)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hệ thống AI Edge NPU tự động phân tích luồng MJPEG thời gian thực để đưa ra phản hồi khẩn cấp.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? BrandTokens.darkTextSecondary
                  : BrandTokens.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_outlined,
                  size: 20, color: BrandTokens.brandAccent),
              SizedBox(width: 8),
              Expanded(
                child: Text('Quy trình xử lý khẩn cấp',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStepRow('1', 'Nhấp "Xem bằng chứng" để kiểm tra ảnh khung hình có phát hiện khói/lửa.'),
          const SizedBox(height: 8),
          _buildStepRow('2', 'Ấn "Tiếp nhận" để xác nhận đang xử lý và kích hoạt còi cảnh báo tại chỗ.'),
          const SizedBox(height: 8),
          _buildStepRow('3', 'Trường hợp có cháy thật, ấn "Gọi PCCC 114" hoặc người thân để gọi tự động.'),
        ],
      ),
    );
  }

  Widget _buildStepRow(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: BrandTokens.brandTint,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: BrandTokens.brandPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
      int index,
      String label, {
        int? count,
        bool highlight = false,
      }) {
    final selected = _filterIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = highlight
        ? (isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg)
        : (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary);

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      backgroundColor: isDark ? BrandTokens.darkSurface : Colors.white,
      selectedColor: accent,
      side: BorderSide(
        color: selected
            ? accent
            : (isDark ? BrandTokens.darkBorder : BrandTokens.border),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      avatar: count != null
          ? CircleAvatar(
        radius: 10,
        backgroundColor: selected
            ? Colors.white.withValues(alpha: 0.20)
            : accent.withValues(alpha: 0.10),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : accent,
          ),
        ),
      )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected
            ? Colors.white
            : (isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => setState(() => _filterIndex = index),
    );
  }
}
