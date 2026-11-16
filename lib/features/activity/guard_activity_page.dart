import 'dart:typed_data';
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

  final Map<int, Uint8List> _incidentSnapshots = {};
  final Set<int> _loadingIncidentSnapshots = {};
  final Set<int> _attemptedIncidentSnapshots = {};

  void _loadSnapshotForIncident(int id, String imageName) {
    if (_attemptedIncidentSnapshots.contains(id) ||
        _loadingIncidentSnapshots.contains(id)) {
      return;
    }
    _loadingIncidentSnapshots.add(id);
    _attemptedIncidentSnapshots.add(id);

    widget.monitoringController.api
        .getIncidentImage(id, imageName)
        .then((bytes) {
      if (!mounted) return;
      setState(() {
        _loadingIncidentSnapshots.remove(id);
        _incidentSnapshots[id] = bytes;
      });
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _loadingIncidentSnapshots.remove(id);
        });
      }
    });
  }

  String? _extractIncidentImageName(Map<String, dynamic> item) {
    final analysisUrl = item['analysis_image_url'] as String?;
    if (analysisUrl != null && analysisUrl.isNotEmpty) {
      final uri = Uri.tryParse(analysisUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        var last = uri.pathSegments.last;
        if (RegExp(r'^\d+$').hasMatch(last)) {
          last = '${last.padLeft(2, '0')}.jpg';
        }
        if (RegExp(r'^(\d{2}|analysis_\d+)\.jpg$').hasMatch(last)) {
          return last;
        }
      }
    }
    final images = item['images'];
    if (images is List && images.isNotEmpty) {
      var first = images.first?.toString();
      if (first != null && first.isNotEmpty) {
        if (RegExp(r'^\d+$').hasMatch(first)) {
          first = '${first.padLeft(2, '0')}.jpg';
        }
        if (RegExp(r'^(\d{2}|analysis_\d+)\.jpg$').hasMatch(first)) {
          return first;
        }
      }
    }
    return null;
  }

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

        final userName = widget.sessionController?.fullName ?? 'Quản trị viên';
        final initials = userName
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join('')
            .toUpperCase();

        return IgnivoPageBody(
          header: IgnivoPageHeader(
            title: 'Cảnh báo',
            subtitle: 'Nhật ký sự cố và phát hiện cháy',
            systemName: widget.sessionController?.systemName ?? 'IGNIVO',
            avatarInitials: initials.isNotEmpty ? initials : 'MA',
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
                            final triggerType = inc['trigger_type']?.toString();

                            final directBytes = inc['image_bytes'] as Uint8List?;
                            final imageBytes = directBytes ?? _incidentSnapshots[id];
                            final imageName =
                                directBytes == null ? _extractIncidentImageName(inc) : null;
                            final analysisUrl = inc['analysis_image_url']?.toString();
                            final snapshotUrl = inc['snapshot_url']?.toString();
                            final imageUrl = (analysisUrl != null &&
                                    (analysisUrl.startsWith('http://') ||
                                        analysisUrl.startsWith('https://')))
                                ? analysisUrl
                                : (snapshotUrl != null &&
                                        (snapshotUrl.startsWith('http://') ||
                                            snapshotUrl.startsWith('https://')))
                                    ? snapshotUrl
                                    : null;

                            if (directBytes == null &&
                                imageUrl == null &&
                                imageName != null &&
                                !_attemptedIncidentSnapshots.contains(id) &&
                                !_loadingIncidentSnapshots.contains(id)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _loadSnapshotForIncident(id, imageName);
                              });
                            }

                            return RecentIncidentTile(
                              id: id,
                              title: 'Sự cố #$id — $area',
                              area: area,
                              timeStr: createdAt.isNotEmpty ? createdAt : 'Vừa xong',
                              severity: severity,
                              status: status,
                              isSimulation: isSim,
                              imageBytes: imageBytes,
                              imageUrl: imageUrl,
                              isImageLoading: _loadingIncidentSnapshots.contains(id),
                              triggerType: triggerType,
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
