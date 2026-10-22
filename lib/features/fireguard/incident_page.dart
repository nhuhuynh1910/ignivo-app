import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import 'package:flutter/services.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/fireguard_realtime_service.dart';
import '../../core/services/incident_alert_coordinator.dart';
import '../../core/theme/brand_tokens.dart';
import '../camera/mjpeg_stream_view.dart';
import '../../widgets/incident_timeline_stepper.dart';
import 'monitor_widgets.dart';

String callStatusLabel(dynamic value) =>
    const {
      'requesting': 'Đang gửi yêu cầu',
      'requested': 'Nhà cung cấp đã nhận yêu cầu',
      'failed': 'Gọi thất bại',
      'ringing': 'Đang đổ chuông',
      'answered': 'Đã nghe máy',
      'busy': 'Máy bận',
      'completed': 'Cuộc gọi đã kết thúc',
      'no_answer': 'Không trả lời',
    }[value] ??
    '$value';

String incidentStatusLabel(dynamic status) =>
    const {
      'analyzing': 'Đang phân tích',
      'ai_dismissed': 'AI nhận định không phải cháy',
      'notifying': 'Đang gọi điện',
      'notified': 'Đã kết thúc lượt gọi',
      'acknowledged': 'Đã nhận xử lý',
      'resolved': 'Đã xử lý',
      'false_alarm': 'Báo nhầm',
      'error': 'Lỗi xử lý',
    }[status] ??
    '$status';

class FireguardIncidentPage extends StatefulWidget {
  const FireguardIncidentPage({
    super.key,
    required this.incidentId,
    this.api,
    this.realtime,
    this.coordinator,
    this.controller,
  });
  final int incidentId;
  final FireguardApiService? api;
  final FireguardRealtimeService? realtime;
  final IncidentAlertCoordinator? coordinator;
  final dynamic controller;
  @override
  State<FireguardIncidentPage> createState() => _FireguardIncidentPageState();
}

class _FireguardIncidentPageState extends State<FireguardIncidentPage>
    with WidgetsBindingObserver {
  late final _api = widget.api ?? FireguardApiService.instance;
  StreamSubscription<FireguardEvent>? _events;
  bool _loadQueued = false;
  int _eventRevision = 0;
  Map<String, dynamic>? _incident;
  String? _error;
  bool _busy = false, _fetching = false, _active = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller != null) {
      try {
        widget.controller.registerDetailedIncident(widget.incidentId);
      } catch (_) {}
    }
    _events = widget.realtime?.events.listen((event) {
      if (_active && event.incidentId == widget.incidentId) {
        _eventRevision++;
        _load();
      }
    });
    _load();

    // Only create private timer if not managed by a parent MonitoringController
    if (widget.controller == null) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_active && !_busy && _api.authToken != null) _load();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _events?.cancel();
    if (widget.controller != null) {
      try {
        widget.controller.unregisterDetailedIncident(widget.incidentId);
      } catch (_) {}
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _load();
  }

  Future<void> _load() async {
    if (_fetching) {
      _loadQueued = true;
      return;
    }
    _fetching = true;
    _loadQueued = false;
    final revision = _eventRevision;
    try {
      final value = await _api.getIncidentDetail(widget.incidentId);
      if (mounted && revision == _eventRevision) {
        if (value != null) widget.coordinator?.syncActiveIncidents([value]);
        setState(() {
          _incident = value;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _fetching = false;
      if (_loadQueued && mounted && _active && _api.authToken != null) {
        _loadQueued = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _act(String action) async {
    final userRole = _api.currentUser?['role']?.toString().toUpperCase();
    if (userRole == 'VIEWER') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản vai trò Chỉ xem (Viewer) không có quyền thao tác trên sự cố.'),
        ),
      );
      return;
    }

    if (action != 'ack') {

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'resolve' ? 'Đóng sự cố?' : 'Xác nhận báo nhầm?',
          ),
          content: const Text(
            'Sự cố sẽ được đóng và FireGuard dừng các cuộc gọi tiếp theo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    final id = widget.incidentId;
    final ok = switch (action) {
      'ack' => await _api.acknowledgeIncident(id),
      'resolve' => await _api.resolveIncident(id),
      _ => await _api.falseAlarmIncident(id),
    };
    if (ok) {
      if (action == 'ack') {
        widget.coordinator?.acknowledgeLocally(id);
      } else {
        widget.coordinator?.stopAlert(incidentId: id);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'FireGuard đã cập nhật sự cố. Các cuộc gọi tiếp theo sẽ dừng.'
              : _api.lastError ?? 'Không thể cập nhật sự cố.',
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final incident = _incident;
    final analysis = incident?['analysis'] as Map?;
    final closed = ['resolved', 'false_alarm'].contains(incident?['status']);
    final images = List<String>.from(incident?['images'] ?? []);
    final analysisUrl = incident?['analysis_image_url'] as String?;
    final imageName = analysisUrl != null
        ? Uri.parse(analysisUrl).pathSegments.last
        : (images.isEmpty ? null : images.first);
    final coordinator = widget.coordinator;
    final isAlarmActive = coordinator?.level == AlertLevel.urgent;
    return Scaffold(
      bottomNavigationBar: incident == null || closed
          ? null
          : SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAlarmActive) ...[
                      if (!coordinator!.isSilenced)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              key: const Key('silence-alarm-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.amber.shade100,
                                foregroundColor: Colors.brown.shade900,
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                setState(() => coordinator.silenceAlarm());
                              },
                              icon: const Icon(Icons.volume_off),
                              label: const Text(
                                'Tắt còi trên điện thoại (Không nhận xử lý)',
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.volume_mute,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Đã tắt chuông cảnh báo trên máy này',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (_api.currentUser?['role']?.toString().toUpperCase() == 'VIEWER') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.visibility_rounded, color: Colors.amber.shade800, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Chế độ Chỉ xem (Viewer): Bạn không có quyền thao tác hay đóng sự cố này.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy || _error != null
                            ? null
                            : () {
                                setState(() {
                                  if (widget.coordinator?.isSilenced == true) {
                                    widget.coordinator?.resumeAlarm();
                                  } else {
                                    widget.coordinator?.silenceAlarm();
                                  }
                                });
                              },
                        icon: Icon(
                          (widget.coordinator?.isSilenced == true)
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 20,
                        ),
                        label: Text(
                          (widget.coordinator?.isSilenced == true)
                              ? 'Bật lại âm thanh'
                              : 'Tắt âm trên thiết bị',
                        ),
                      ),
                    ] else ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                          ),
                          backgroundColor: BrandTokens.criticalFg,
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                        ),
                        onPressed:
                            _busy ||
                                _error != null ||
                                incident['status'] == 'acknowledged'
                            ? null
                            : () {
                                HapticFeedback.heavyImpact();
                                _act('ack');
                              },
                        icon: Icon(
                          incident['status'] == 'acknowledged'
                              ? Icons.check_circle_outline_rounded
                              : Icons.front_hand_rounded,
                          size: 20,
                        ),
                        label: Text(
                          incident['status'] == 'acknowledged'
                              ? 'Đã nhận xử lý'
                              : 'Nhận xử lý • Dừng gọi tiếp',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                          ),
                        ),
                        onPressed: _busy || _error != null
                            ? null
                            : () {
                                setState(() {
                                  if (widget.coordinator?.isSilenced == true) {
                                    widget.coordinator?.resumeAlarm();
                                  } else {
                                    widget.coordinator?.silenceAlarm();
                                  }
                                });
                              },
                        icon: Icon(
                          (widget.coordinator?.isSilenced == true)
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 20,
                        ),
                        label: Text(
                          (widget.coordinator?.isSilenced == true)
                              ? 'Bật lại âm thanh'
                              : 'Tắt âm trên thiết bị',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                                ),
                              ),
                              onPressed: _busy || _error != null
                                  ? null
                                  : () {
                                      HapticFeedback.mediumImpact();
                                      _act('resolve');
                                    },
                              child: const Text('Đã xử lý xong'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(80, 46),
                              foregroundColor: Colors.red.shade400,
                            ),
                            onPressed: _busy || _error != null
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    _act('false-alarm');
                                  },
                            child: const Text('Báo nhầm'),
                          ),
                        ],
                      ),
                    ],

                  ],
                ),
              ),
            ),
          ),
        ),
      appBar: ignivoDetailAppBar(
        context,
        title: 'Sự cố #${widget.incidentId}',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Không thể cập nhật. $_error',
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (incident == null && _error == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (incident != null) ...[
                _buildHeroCard(context, incident),
                if (incident['status'] == 'ai_dismissed') ...[
                  _buildAiDismissedBanner(context),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IncidentTimelineStepper(incident: incident),
                ),
                _buildEvidenceCard(context, incident, imageName),
                _buildAiAnalysisCard(context, incident, analysis),
                _buildAdditionalEvidenceCard(context, images, imageName),
                _buildVoiceMessageCard(context, incident),
                _buildCallHistoryCard(context, incident),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Map<String, dynamic> incident) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = incident['status'];
    final isClosed = ['resolved', 'false_alarm'].contains(status);
    final trigger = incident['trigger_type'];
    final isSimulation = incident['is_simulation'] == true || trigger == 'simulation';

    Color cardBorderColor = isDark ? BrandTokens.darkBorder : BrandTokens.border;
    if (!isClosed) {
      cardBorderColor = isDark
          ? BrandTokens.darkCriticalFg.withValues(alpha: 0.5)
          : BrandTokens.criticalFg.withValues(alpha: 0.35);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (isClosed ? Colors.black : BrandTokens.criticalFg).withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SỰ CỐ #${widget.incidentId}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? (isDark ? BrandTokens.darkSurfaceVariant : Colors.grey.shade100)
                        : (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isClosed
                          ? (isDark ? BrandTokens.darkBorder : Colors.grey.shade300)
                          : (isDark ? BrandTokens.darkCriticalFg.withValues(alpha: 0.4) : Colors.red.shade200),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isClosed)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        isClosed ? 'ĐÃ ĐÓNG' : 'ĐANG XỬ LÝ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isClosed
                              ? (isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary)
                              : (isDark ? Colors.red.shade200 : Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              IncidentPresentationHelper.cameraName(incident),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${IncidentPresentationHelper.areaText(incident)} · ${incident['created_at'] ?? ''}'
                        .replaceAll('T', ' '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GuardBadge(
                  incidentStatusLabel(incident['status']),
                  color: (incident['status'] == 'resolved' || incident['status'] == 'acknowledged')
                      ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
                      : (isClosed
                          ? BrandTokens.stitchOnlineFg
                          : BrandTokens.stitchCriticalFg),
                ),
                GuardBadge(
                  IncidentPresentationHelper.severityLabel(incident['severity']),
                  color: BrandTokens.criticalFg,
                ),
                GuardBadge(
                  '${incident['trigger_type']}'.toUpperCase(),
                  color: BrandTokens.textSecondary,
                ),
                if (isSimulation)
                  const GuardBadge('Mô phỏng', color: BrandTokens.stitchWarningFg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiDismissedBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Colors.amber.shade900.withValues(alpha: 0.25) : Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        side: BorderSide(color: Colors.amber.shade400),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: isDark ? Colors.amber.shade200 : Colors.amber.shade900),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI bổ sung nhận định không phải cháy; cần kiểm tra bằng chứng',
                style: TextStyle(
                  color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCard(BuildContext context, Map<String, dynamic> incident, String? imageName) {
    if (imageName == null && incident['camera_id'] == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ảnh chụp bằng chứng phát hiện',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkSurfaceVariant : Colors.blueGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'NPU Snapshot',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? BrandTokens.darkTextSecondary : Colors.blueGrey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (imageName != null) ...[
              const SizedBox(height: 12),
              GuardIncidentImage(
                key: ValueKey(imageName),
                incidentId: widget.incidentId,
                name: imageName,
                api: _api,
              ),
            ],
            if (incident['camera_id'] != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                    foregroundColor: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: Text(
                              IncidentPresentationHelper.cameraName(incident),
                            ),
                          ),
                          body: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: MjpegStreamView(
                                streamUrl: _api.getMjpegStreamUrl(
                                  incident['camera_id'],
                                ),
                                requestHeaders: _api.headersForUrl(
                                  _api.getMjpegStreamUrl(incident['camera_id']),
                                ),
                                height: 300,
                                showStats: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam_rounded, size: 20),
                  label: Text(
                    'Mở camera liên quan (${IncidentPresentationHelper.cameraName(incident)})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisCard(BuildContext context, Map<String, dynamic> incident, Map? analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flammableObjects = (analysis?['flammable_objects'] as List? ?? []);
    final recommendedActions = (analysis?['recommended_actions'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân tích Trí tuệ Nhân tạo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (analysis != null)
                        Text(
                          'Mô hình: ${analysis['model'] ?? 'Gemini 1.5 Flash'} (Bổ sung)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (analysis != null)
                  GuardBadge('Gemini · ${analysis['model'] ?? '—'} (Bổ sung)'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? BrandTokens.darkSurfaceVariant : const Color(0xFFF6F8FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  width: 0.8,
                ),
              ),
              child: Text(
                '${analysis?['summary_vi'] ?? incident['analysis_error'] ?? 'Chưa có phân tích AI.'}',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                ),
              ),
            ),
            if (flammableObjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Vật dễ cháy phát hiện',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final object in flammableObjects)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkSurfaceVariant : Colors.red.shade50.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? BrandTokens.darkBorder : Colors.red.shade100,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${object['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      if (object['distance'] != null && '${object['distance']}'.isNotEmpty)
                        Text(
                          '${object['distance']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                          ),
                        ),
                      if (object['risk'] != null && '${object['risk']}'.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (object['risk'] == 'high' || object['risk'] == 'cao')
                                ? Colors.red.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${object['risk']}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (object['risk'] == 'high' || object['risk'] == 'cao')
                                  ? Colors.red.shade900
                                  : Colors.brown.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            if (recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Khuyến nghị ứng phó an toàn',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < recommendedActions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${recommendedActions[i]}',
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalEvidenceCard(BuildContext context, List<String> images, String? imageName) {
    final otherImages = images.where((name) => name != imageName).toList();
    if (otherImages.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: ExpansionTile(
        key: const PageStorageKey('incident_evidence_images_tile'),
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.photo_library_outlined,
            size: 18,
            color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
          ),
        ),
        title: Text(
          'Ảnh bằng chứng (${images.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                for (final name in otherImages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GuardIncidentImage(
                      key: ValueKey(name),
                      incidentId: widget.incidentId,
                      name: name,
                      api: _api,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessageCard(BuildContext context, Map<String, dynamic> incident) {
    final voiceMessage = incident['voice_message']?.toString() ?? '';
    if (voiceMessage.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: ExpansionTile(
        key: const PageStorageKey('incident_voice_message_tile'),
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.record_voice_over_outlined,
            size: 18,
            color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
          ),
        ),
        title: const Text(
          'Nội dung cuộc gọi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? BrandTokens.darkSurfaceVariant : const Color(0xFFF9FAFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  width: 0.8,
                ),
              ),
              child: Text(
                voiceMessage,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHistoryCard(BuildContext context, Map<String, dynamic> incident) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calls = (incident['calls'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.phone_in_talk_rounded,
                    size: 18,
                    color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Lịch sử cuộc gọi khẩn cấp',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (calls.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${calls.length} lượt gọi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (calls.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Chưa có cuộc gọi được ghi nhận.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                    ),
                  ),
                ),
              )
            else
              for (final call in calls)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkSurfaceVariant : const Color(0xFFF9FAFD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (call['status'] == 'answered' || call['status'] == 'completed')
                              ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
                              : (call['status'] == 'ringing' || call['status'] == 'requesting')
                                  ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50)
                                  : (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (call['status'] == 'answered' || call['status'] == 'completed')
                              ? Icons.phone_callback_rounded
                              : (call['status'] == 'ringing' || call['status'] == 'requesting')
                                  ? Icons.ring_volume_rounded
                                  : Icons.phone_missed_rounded,
                          size: 16,
                          color: (call['status'] == 'answered' || call['status'] == 'completed')
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                              : (call['status'] == 'ringing' || call['status'] == 'requesting')
                                  ? (isDark ? Colors.amber.shade300 : Colors.amber.shade800)
                                  : (isDark ? Colors.red.shade300 : Colors.red.shade700),
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
                                    '${call['contact_name']} • ${call['phone']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (call['status'] == 'answered' || call['status'] == 'completed')
                                        ? (isDark ? Colors.green.shade900.withValues(alpha: 0.4) : Colors.green.shade100)
                                        : (isDark ? Colors.amber.shade900.withValues(alpha: 0.4) : Colors.amber.shade100),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    callStatusLabel(call['status']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: (call['status'] == 'answered' || call['status'] == 'completed')
                                          ? (isDark ? Colors.green.shade200 : Colors.green.shade900)
                                          : (isDark ? Colors.amber.shade200 : Colors.brown.shade900),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              call['provider'] == 'mock' ? 'Giả lập — không gọi thật' : 'Tổng đài tự động',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                              ),
                            ),
                            if (call['error'] != null && '${call['error']}'.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Lỗi: ${call['error']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
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
      ),
    );
  }
}

class GuardIncidentImage extends StatefulWidget {
  const GuardIncidentImage({
    super.key,
    required this.incidentId,
    required this.name,
    required this.api,
  });

  final int incidentId;
  final String name;
  final FireguardApiService api;

  @override
  State<GuardIncidentImage> createState() => _IncidentImageState();
}

class _IncidentImageState extends State<GuardIncidentImage> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant GuardIncidentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentId != widget.incidentId ||
        oldWidget.name != widget.name) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await widget.api.getIncidentImage(
        widget.incidentId,
        widget.name,
      );
      if (mounted && gen == _generation) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && gen == _generation) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _openFullscreen(BuildContext context) {
    if (_bytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            title: Text('Ảnh bằng chứng: ${widget.name}'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Đang tải ảnh bằng chứng...',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không tải được ảnh: $_error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadImage,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tải lại ảnh'),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          GestureDetector(
            onTap: () => _openFullscreen(context),
            child: Image.memory(_bytes!, fit: BoxFit.contain),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              onPressed: () => _openFullscreen(context),
              icon: const Icon(Icons.zoom_in, size: 16),
              label: const Text('Xem phóng to', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
