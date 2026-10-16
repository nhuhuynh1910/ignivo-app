import 'package:flutter/material.dart';
import '../../core/services/system_session_controller.dart';
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
  int _filterIndex = 0; // 0: Tất cả, 1: Cần chú ý, 2: Đang xử lý, 3: Đã kết thúc, 4: Mô phỏng

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
        return ['analyzing', 'notifying', 'notified', 'ai_dismissed'].contains(status);
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

  Color _severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade800;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
      default:
        return Colors.blueGrey;
    }
  }

  IconData _triggerIcon(String? trigger) {
    switch (trigger?.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'smoke':
        return Icons.cloud_outlined;
      case 'thermal':
        return Icons.thermostat;
      case 'simulation':
        return Icons.science_outlined;
      default:
        return Icons.warning_amber_rounded;
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

        return RefreshIndicator(
          onRefresh: widget.monitoringController.refresh,
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
                            .where((i) => [
                                  'analyzing',
                                  'notifying',
                                  'notified',
                                  'ai_dismissed',
                                ].contains(i['status']))
                            .length,
                        highlight: true,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        2,
                        'Đang xử lý',
                        count: allIncidents.where((i) => i['status'] == 'acknowledged').length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        3,
                        'Đã kết thúc',
                        count: allIncidents
                            .where((i) => ['resolved', 'false_alarm'].contains(i['status']))
                            .length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        4,
                        'Mô phỏng',
                        count: allIncidents
                            .where((i) =>
                                i['is_simulation'] == true ||
                                i['trigger_type']?.toString().toLowerCase() == 'simulation')
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
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.history_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 14),
                                Text(
                                  allIncidents.isEmpty
                                      ? 'Chưa ghi nhận sự cố nào'
                                      : 'Không có sự cố nào trong bộ lọc này',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final inc = filtered[index];
                          final id = inc['id'] as int? ?? 0;
                          final area = inc['area']?.toString() ?? 'Chưa xác định';
                          final status = inc['status']?.toString();
                          final statusLabel = incidentStatusLabel(status);
                          final severity = inc['severity']?.toString();
                          final trigger = inc['trigger_type']?.toString();
                          final createdAt = inc['created_at']?.toString() ?? '';
                          final isUnclosed = !['resolved', 'false_alarm'].contains(status);

                          return InkWell(
                            onTap: () => _navigateToDetail(context, id),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isUnclosed
                                      ? _severityColor(severity).withValues(alpha: 0.5)
                                      : theme.dividerColor.withValues(alpha: 0.12),
                                  width: isUnclosed ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        _severityColor(severity).withValues(alpha: 0.12),
                                    child: Icon(
                                      _triggerIcon(trigger),
                                      color: _severityColor(severity),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Sự cố #$id — $area',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (severity != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _severityColor(severity)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  severity.toUpperCase(),
                                                  style: TextStyle(
                                                    color: _severityColor(severity),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isUnclosed ? Colors.red : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isUnclosed
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: isUnclosed ? Colors.red.shade700 : null,
                                              ),
                                            ),
                                            if (createdAt.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '· $createdAt',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme.textTheme.bodySmall?.color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(int index, String label, {int? count, bool highlight = false}) {
    final selected = _filterIndex == index;
    final theme = Theme.of(context);

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: count != null && count > 0
          ? CircleAvatar(
              radius: 8,
              backgroundColor: highlight ? Colors.red.shade700 : theme.colorScheme.primary,
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      label: Text(label),
      onSelected: (_) => setState(() => _filterIndex = index),
      selectedColor: highlight
          ? Colors.red.withValues(alpha: 0.15)
          : theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected
            ? (highlight ? Colors.red.shade900 : theme.colorScheme.onPrimaryContainer)
            : null,
      ),
    );
  }
}
