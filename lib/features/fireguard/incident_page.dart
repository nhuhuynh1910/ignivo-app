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
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.volume_mute,
                                size: 16,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Đã tắt chuông cảnh báo trên máy này',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: BrandTokens.criticalFg,
                        foregroundColor: Colors.white,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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
            padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Text('Không thể cập nhật. $_error'),
          if (incident == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (incident != null) ...[
            Text(
              IncidentPresentationHelper.cameraName(incident),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${IncidentPresentationHelper.areaText(incident)} · ${incident['created_at'] ?? ''}'
                  .replaceAll('T', ' '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GuardBadge(
                  incidentStatusLabel(incident['status']),
                  color:
                      ['resolved', 'false_alarm'].contains(incident['status'])
                          ? BrandTokens.stitchOnlineFg
                          : BrandTokens.stitchCriticalFg,
                ),
                GuardBadge(
                  IncidentPresentationHelper.severityLabel(
                    incident['severity'],
                  ),
                  color: BrandTokens.criticalFg,
                ),
                GuardBadge(
                  '${incident['trigger_type']}'.toUpperCase(),
                  color: BrandTokens.textSecondary,
                ),
                if (incident['is_simulation'] == true)
                  const GuardBadge('Mô phỏng', color: BrandTokens.stitchWarningFg),
              ],
            ),
            if (incident['status'] == 'ai_dismissed') ...[
              Card(
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade400),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AI bổ sung nhận định không phải cháy; cần kiểm tra bằng chứng',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            IncidentTimelineStepper(incident: incident),
            if (imageName != null) ...[
              GuardIncidentImage(
                key: ValueKey(imageName),
                incidentId: widget.incidentId,
                name: imageName,
                api: _api,
              ),
              const SizedBox(height: 12),
            ],
            if (incident['camera_id'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
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
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(
                    'Mở camera liên quan (${IncidentPresentationHelper.cameraName(incident)})',
                  ),
                ),
              ),
            Text(
              '${analysis?['summary_vi'] ?? incident['analysis_error'] ?? 'Chưa có phân tích AI.'}',
            ),
            if (analysis != null) ...[
              const SizedBox(height: 12),
              GuardBadge('Gemini · ${analysis['model'] ?? '—'} (Bổ sung)'),
              if ((analysis['flammable_objects'] as List? ?? []).isNotEmpty)
                GuardPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vật dễ cháy',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final object in analysis['flammable_objects'])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.local_fire_department_outlined,
                          ),
                          title: Text('${object['name']}'),
                          subtitle: Text(
                            '${object['distance'] ?? ''} · ${object['risk'] ?? ''}',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            if (images.where((name) => name != imageName).isNotEmpty)
              ExpansionTile(
                key: const PageStorageKey('incident_evidence_images_tile'),
                title: Text('Ảnh bằng chứng (${images.length})'),
                children: [
                  for (final name in images.where((name) => name != imageName))
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
            if ('${incident['voice_message'] ?? ''}'.isNotEmpty)
              ExpansionTile(
                key: const PageStorageKey('incident_voice_message_tile'),
                title: const Text('Nội dung cuộc gọi'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('${incident['voice_message']}'),
                  ),
                ],
              ),
            for (final action in analysis?['recommended_actions'] ?? [])
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('$action'),
              ),
            const SizedBox(height: 16),
            const Divider(),
            Text(
              'Lịch sử cuộc gọi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final call in incident['calls'] ?? [])
              ListTile(
                title: Text('${call['contact_name']} • ${call['phone']}'),
                subtitle: Text(
                  '${call['provider'] == 'mock' ? 'Giả lập — không gọi thật' : 'Cuộc gọi'} • ${callStatusLabel(call['status'])}${call['error'] == null ? '' : '\n${call['error']}'}',
                ),
              ),
            if ((incident['calls'] as List? ?? []).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Chưa có cuộc gọi được ghi nhận.'),
              ),
          ],
        ],
      ),
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
