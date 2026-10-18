import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/recent_incident_tile.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
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
  int _filterIndex =
      0; // 0: Tất cả, 1: Cần chú ý, 2: Đang xử lý, 3: Đã kết thúc, 4: Mô phỏng

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
      case 1: // Cần chú ý
        return [
          'analyzing',
          'notifying',
          'notified',
          'ai_dismissed',
        ].contains(status);
      case 2: // Đang xử lý
        return status == 'acknowledged';
      case 3: // Đã kết thúc
        return ['resolved', 'false_alarm'].contains(status);
      case 4: // Mô phỏng
        return isSim;
      case 0: // Tất cả
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.monitoringController,
      builder: (context, _) {
        final allIncidents = widget.monitoringController.incidents;
        final filtered = allIncidents.where(_matchesFilter).toList();

        return IgnivoPageBody(
          header: IgnivoPageHeader(
            title: 'Cảnh báo',
            systemName: widget.sessionController?.systemName ?? 'IGNIVO',
            showSync: true,
            updatedAt: widget.monitoringController.updated,
            stale: widget.monitoringController.stale,
            action: IgnivoHeaderAction(
              icon: Icons.refresh,
              tooltip: 'Làm mới hoạt động',
              onPressed: widget.monitoringController.refresh,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: widget.monitoringController.refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    // Sticky Filter Bar
                Container(
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(0, 'Tất cả (${allIncidents.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          1,
                          'Cần chú ý',
                          count: allIncidents
                              .where(
                                (i) => [
                                  'analyzing',
                                  'notifying',
                                  'notified',
                                  'ai_dismissed',
                                ].contains(i['status']),
                              )
                              .length,
                          highlight: true,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          2,
                          'Đang xử lý',
                          count: allIncidents
                              .where((i) => i['status'] == 'acknowledged')
                              .length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          3,
                          'Đã kết thúc',
                          count: allIncidents
                              .where(
                                (i) => [
                                  'resolved',
                                  'false_alarm',
                                ].contains(i['status']),
                              )
                              .length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          4,
                          'Mô phỏng',
                          count: allIncidents
                              .where(
                                (i) =>
                                    i['is_simulation'] == true ||
                                    i['trigger_type']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'simulation',
                              )
                              .length,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Incident List
                Expanded(
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    allIncidents.isEmpty
                                        ? 'Chưa ghi nhận sự cố nào'
                                        : 'Không có sự cố nào trong bộ lọc này',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    allIncidents.isEmpty
                                        ? 'Hệ thống FireGuard ghi nhận tối đa 50 sự cố gần nhất.'
                                        : 'Hãy chọn bộ lọc khác để xem các sự cố liên quan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.textTheme.bodySmall?.color,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final inc = filtered[index];
                            final id = inc['id'] as int? ?? 0;
                            final area =
                                inc['area']?.toString() ?? 'Chưa xác định';
                            final status = inc['status']?.toString();
                            final severity = inc['severity']?.toString();
                            final createdAt =
                                inc['created_at']?.toString() ?? '';
                            final isSim = inc['is_simulation'] == true ||
                                inc['trigger_type']?.toString().toLowerCase() ==
                                    'simulation';

                            return RecentIncidentTile(
                              id: id,
                              title: 'Sự cố #$id — $area',
                              area: area,
                              timeStr: createdAt.isNotEmpty ? createdAt : 'Vừa xong',
                              severity: severity,
                              status: status,
                              isSimulation: isSim,
                              onTap: () => _navigateToDetail(context, id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
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

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? (highlight ? Colors.red.shade700 : BrandTokens.brandPrimary)
              : theme.dividerColor.withValues(alpha: 0.15),
          width: selected ? 1.5 : 1,
        ),
      ),
      avatar: count != null && count > 0
          ? CircleAvatar(
              radius: 8,
              backgroundColor: highlight
                  ? Colors.red.shade700
                  : BrandTokens.brandPrimary,
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      label: Text(label),
      onSelected: (_) => setState(() => _filterIndex = index),
      selectedColor: highlight
          ? Colors.red.withValues(alpha: 0.15)
          : BrandTokens.brandPrimary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected
            ? (highlight
                  ? Colors.red.shade900
                  : BrandTokens.brandPrimary)
            : null,
      ),
    );
  }
}
