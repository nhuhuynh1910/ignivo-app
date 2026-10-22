import 'dart:async';
import '../../core/services/fireeye_api_service.dart';
import 'people_page.dart';
import 'eye_events_page.dart';
import 'pi_camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/fireguard_realtime_service.dart';
import '../camera/mjpeg_stream_view.dart';
import '../settings/emergency_contacts_page.dart';
import '../settings/emergency_location_page.dart';
import 'incident_page.dart';
import 'monitor_widgets.dart';
import 'camera_editor_page.dart';
import '../../core/services/incident_alert_coordinator.dart';
import '../../core/theme/brand_tokens.dart';

/// Uses FireGuard data directly, without Firebase pairing or ID conversion.
class FireguardPage extends StatefulWidget {
  const FireguardPage({
    super.key,
    this.api,
    this.realtime,
    this.eye,
    this.coordinator,
  });
  final FireeyeApiService? eye;
  final FireguardApiService? api;
  final FireguardRealtimeService? realtime;
  final IncidentAlertCoordinator? coordinator;
  @override
  State<FireguardPage> createState() => _FireguardPageState();
}

class _FireguardPageState extends State<FireguardPage>
    with WidgetsBindingObserver {
  late final _api = widget.api ?? FireguardApiService.instance;
  late final _realtime = widget.realtime ?? FireguardRealtimeService(_api);
  late final _coordinator =
      widget.coordinator ??
      IncidentAlertCoordinator(api: _api, realtime: _realtime);
  StreamSubscription<FireguardEvent>? _events;
  Map<String, dynamic>? _activeIncident;
  final _announced = <int>{};
  bool _refreshQueued = false;
  int _eventRevision = 0;
  List<Map<String, dynamic>> _cameras = [], _incidents = [];
  Map<String, dynamic>? _status;
  Timer? _timer;
  bool _loading = true, _fetching = false, _foreground = true;
  String? _error;
  DateTime? _updated;
  int _tab = 0, _filter = 0;
  int? _cameraId;
  bool _covered = false, _fresh = false;
  bool _resumeAfterRefresh = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.addListener(_connectionChanged);
    _coordinator.addListener(_onCoordinatorChanged);
    _events = _realtime.events.listen(_onEvent);
    _realtime.start();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_foreground &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          _api.authToken != null) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _events?.cancel();
    _coordinator.removeListener(_onCoordinatorChanged);
    if (widget.coordinator == null) {
      _coordinator.dispose();
    }
    _realtime.removeListener(_connectionChanged);
    if (widget.realtime == null) {
      _realtime.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resumeAfterRefresh = true;
      _realtime.start();
      _refresh();
    } else {
      _eventRevision++;
      _coordinator.pauseFeedback();
      _fresh = false;
      _realtime.stop();
    }
  }

  void _connectionChanged() {
    if (!mounted) return;
    setState(() {});
    if (_realtime.state == FireguardConnection.connected) _refresh();
  }

  void _onCoordinatorChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onEvent(FireguardEvent event) {
    if (!mounted || !_foreground) return;
    _eventRevision++;
    if (event.name == 'incident.created' && _announced.add(event.incidentId!)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${event.data['is_simulation'] == true ? 'GIẢ LẬP' : 'CẢNH BÁO'}: FireGuard phát hiện sự cố #${event.incidentId}',
          ),
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => _openIncident(event.incidentId!),
          ),
        ),
      );
    }
    _refresh();
  }

  void _openIncident(int id) => _open(
    FireguardIncidentPage(
      incidentId: id,
      api: _api,
      realtime: _realtime,
      coordinator: _coordinator,
    ),
  );

  Future<void> _refresh() async {
    if (_fetching) {
      _refreshQueued = true;
      return;
    }
    _fetching = true;
    _refreshQueued = false;
    final revision = _eventRevision;
    final session = _api.sessionRevision;
    final origin = _api.baseUrl;
    try {
      await _api.getCurrentUser();
      final status = await _api.getSystemStatus();
      if (status == null) {
        throw FireguardException(
          _api.lastError ?? 'Không tải được trạng thái.',
        );
      }
      final cameras = await _api.getCameras();
      final incidents = await _api.getIncidents();
      final active = await _api.getActiveIncident();
      final syncList = <Map<String, dynamic>>[?active, ...incidents];
      // Limited lists cannot confirm that a previously tracked incident ended.
      // Fetch missing IDs explicitly to recover ACK/close events missed offline.
      final listedIds = syncList.map((i) => i['id']).toSet();
      for (final id in _coordinator.trackedIncidentIds) {
        if (!listedIds.contains(id)) {
          final detail = await _api.getIncidentDetail(id);
          if (detail != null) syncList.add(detail);
        }
      }
      if (mounted &&
          _foreground &&
          revision == _eventRevision &&
          session == _api.sessionRevision &&
          origin == _api.baseUrl) {
        _coordinator.syncActiveIncidents(syncList);
        if (_resumeAfterRefresh) {
          _resumeAfterRefresh = false;
          _coordinator.resumeFeedback();
        }
        setState(() {
          _status = status;
          _cameras = cameras;
          _incidents = incidents;
          _activeIncident = active;
          _error = null;
          _updated = DateTime.now();
          _fresh = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
      if (_refreshQueued && mounted && _foreground && _api.authToken != null) {
        _refreshQueued = false;
        unawaited(_refresh());
      }
    }
  }

  Future<void> _open(Widget page) async {
    setState(() => _covered = true);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() => _covered = false);
      await _refresh();
    }
  }

  bool get _stale => _error != null || !_fresh;
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  List<dynamic> get _classes =>
      (_status?['vision']?['model_classes'] as List?) ?? [];
  String get _connectionLabel => switch (_realtime.state) {
    FireguardConnection.connected => 'Đã kết nối cảnh báo trực tiếp',
    FireguardConnection.connecting => 'Đang kết nối cảnh báo…',
    FireguardConnection.reconnecting => 'Mất kết nối cảnh báo — đang thử lại',
    FireguardConnection.expired => 'Phiên hết hạn — cần đăng nhập lại',
    FireguardConnection.stopped => 'Cảnh báo trực tiếp tạm dừng',
  };

  Widget _heading(String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );

  Widget _incidentCard(Map<String, dynamic> incident) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmoke =
        incident['trigger_type'].toString().toLowerCase() == 'smoke';
    final id = incident['id'];
    final title = IncidentPresentationHelper.formatIncidentTitle(incident);
    final timeFormatted =
        IncidentPresentationHelper.formatTimestamp(incident['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          isSmoke ? Icons.cloud_outlined : Icons.local_fire_department_outlined,
          color: isSmoke ? Colors.blueGrey : BrandTokens.stitchCriticalFg,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GuardBadge(
                  incidentStatusLabel(incident['status']),
                  color: (incident['status'] == 'resolved' || incident['status'] == 'acknowledged')
                      ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
                      : (['resolved', 'false_alarm'].contains(incident['status'])
                          ? Colors.teal
                          : BrandTokens.stitchCriticalFg),
                ),
                GuardBadge('#$id', color: Colors.blueGrey),
                if (incident['is_simulation'] == true)
                  const GuardBadge('Mô phỏng', color: Colors.amber),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${incident['analysis']?['summary_vi'] ?? incident['analysis_error'] ?? 'Chưa có phân tích Gemini.'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (timeFormatted.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeFormatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openIncident(incident['id'] as int),
      ),
    );
  }

  List<Widget> _live() {
    final enabled = _cameras.where((c) => c['enabled'] != false).toList();
    final selected =
        enabled.where((c) => c['id'] == _cameraId).firstOrNull ??
        enabled.firstOrNull;
    final onlineCount = _cameras
        .where((c) => c['enabled'] != false && c['status']?['online'] == true)
        .length;
    final vision = _status?['vision'] as Map? ?? {};
    final latest = selected == null
        ? null
        : _incidents
              .where(
                (i) =>
                    i['camera_id'] == selected['id'] &&
                    i['analysis_image_url'] != null,
              )
              .firstOrNull;
    return [
      _heading('Tổng quan', 'Giám sát trực tiếp và trạng thái hệ thống IGNIVO'),
      if (enabled.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final c in enabled)
                ChoiceChip(
                  label: Text('${c['name']}'),
                  selected: c['id'] == selected?['id'],
                  onSelected: (_) => setState(() => _cameraId = c['id'] as int),
                ),
            ],
          ),
        ),
      if (enabled.isEmpty)
        GuardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 36),
              const SizedBox(height: 12),
              const Text('Chưa có camera đang bật.'),
              TextButton(
                onPressed: () => setState(() => _tab = 2),
                child: const Text('Mở quản lý camera'),
              ),
            ],
          ),
        ),
      if (selected != null)
        GuardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selected['name']}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if ('${selected['area'] ?? ''}'.isNotEmpty)
                Text('${selected['area']}'),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      !_stale &&
                          _foreground &&
                          !_covered &&
                          _api.authToken != null &&
                          selected['status']?['online'] == true &&
                          _status?['detection_source'] == 'local'
                      ? LayoutBuilder(
                          builder: (_, box) => MjpegStreamView(
                            key: ValueKey('stream-${selected['id']}'),
                            streamUrl: _api.getMjpegStreamUrl(selected['id']),
                            requestHeaders: _api.headersForUrl(
                              _api.getMjpegStreamUrl(selected['id']),
                            ),
                            height: box.maxHeight,
                            showStats: false,
                          ),
                        )
                      : ColoredBox(
                          color: const Color(0xff202b39),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off_outlined,
                                  size: 36,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _covered || !_foreground
                                      ? 'Tạm dừng xem trực tiếp'
                                      : 'Không có hình trực tiếp',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              CameraTelemetry(
                camera: selected,
                stale: _stale,
                modelClasses: _classes,
              ),
            ],
          ),
        ),
      if (selected != null && latest != null)
        GuardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phân tích Gemini gần nhất',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Sự cố #${latest['id']} · ${latest['created_at'] ?? ''}${latest['is_simulation'] == true ? ' · Mô phỏng' : ''}',
              ),
              const SizedBox(height: 10),
              GuardIncidentImage(
                key: ValueKey(
                  '${latest['id']}-${latest['analysis_image_url']}',
                ),
                api: _api,
                incidentId: latest['id'] as int,
                name: Uri.parse(latest['analysis_image_url']).pathSegments.last,
              ),
              const SizedBox(height: 10),
              Text('${latest['analysis']?['summary_vi'] ?? 'Đang phân tích…'}'),
              TextButton(
                onPressed: () => _openIncident(latest['id'] as int),
                child: const Text('Xem chi tiết sự cố'),
              ),
            ],
          ),
        ),
      _readiness(),
      _deviceTelemetry(onlineCount, vision),
    ];
  }

  Widget _deviceTelemetry(int onlineCount, Map vision) => GuardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_status?['hostname'] ?? 'FireGuard'}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GuardBadge(
              _stale
                  ? 'Camera: chưa cập nhật'
                  : '$onlineCount/${_cameras.length} camera online',
              color: onlineCount > 0 && !_stale ? Colors.teal : Colors.orange,
            ),
            GuardBadge(
              _stale
                  ? 'AI: chưa cập nhật'
                  : '${vision['detector'] == 'mock' ? 'AI giả lập' : 'Hailo'} · ${_status?['total_ai_fps'] ?? '—'} fps',
              color: vision['ready'] == true && !_stale
                  ? Colors.blue
                  : Colors.orange,
            ),
            GuardBadge(
              'CPU ${_stale ? '—' : _status?['cpu_temp_c'] ?? '—'} °C',
            ),
          ],
        ),
        if (_status?['detection_source'] != null &&
            _status?['detection_source'] != 'local')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Camera trực tiếp cần FireGuard chạy chế độ local.'),
          ),
      ],
    ),
  );

  List<Widget> _incidentList() {
    final list = _incidents.where((i) {
      final closed = ['resolved', 'false_alarm'].contains(i['status']);
      return switch (_filter) {
        1 => !closed,
        2 => closed,
        3 => i['is_simulation'] == true,
        _ => true,
      };
    }).toList();
    return [
      if (widget.eye != null)
        OutlinedButton.icon(
          onPressed: () => _open(EyeEventsPage(eye: widget.eye!)),
          icon: const Icon(Icons.history),
          label: const Text('Lịch sử khuôn mặt và sự kiện FireEye'),
        ),
      _heading(
        'Lịch sử nhận diện',
        'Nhật ký phát hiện và tiến trình xử lý · tối đa 50 sự cố gần nhất',
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < 4; i++)
              ChoiceChip(
                label: Text(['Tất cả', 'Đang mở', 'Đã đóng', 'Mô phỏng'][i]),
                selected: _filter == i,
                onSelected: (_) => setState(() => _filter = i),
              ),
          ],
        ),
      ),
      if (list.isEmpty)
        GuardPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _stale
                        ? BrandTokens.stitchWarning.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _stale
                        ? Icons.cloud_off_outlined
                        : Icons.filter_list_off_rounded,
                    color: _stale
                        ? BrandTokens.stitchWarningFg
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stale
                            ? 'Mất kết nối hoặc dữ liệu cũ'
                            : 'Không có sự cố trong bộ lọc này',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Không có sự cố trong nhóm này.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_updated != null || _stale) ...[
                        const SizedBox(height: 3),
                        Text(
                          _stale
                              ? 'Dữ liệu cũ · Đang kết nối lại Pi'
                              : 'Cập nhật lần cuối: ${_formatTime(_updated!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _stale
                                ? BrandTokens.stitchWarningFg
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ...list.map(_incidentCard),
    ];
  }

  List<Widget> _cameraList() => [
    _heading('Camera', 'Quản lý nguồn hình và AI trên Pi'),
    if (_api.canConfigure)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FilledButton.icon(
          onPressed: _stale ? null : () => _open(GuardCameraEditor(api: _api)),
          icon: const Icon(Icons.add),
          label: const Text('Thêm camera'),
        ),
      ),
    if (_cameras.isEmpty)
      const GuardPanel(child: Text('Chưa có camera trên FireGuard.')),
    for (final c in _cameras)
      GuardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.videocam_outlined),
              title: Text('${c['name']}'),
              subtitle: Text('${c['area'] ?? ''} · ${c['source_type'] ?? ''}'),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GuardBadge(
                  cameraHealth(c, stale: _stale),
                  color: !_stale && c['status']?['online'] == true
                      ? Colors.teal
                      : Colors.orange,
                ),
                GuardBadge(c['detect_enabled'] == false ? 'AI tắt' : 'AI bật'),
                GuardBadge('Mục tiêu AI: ${c['ai_fps'] ?? '—'} fps'),
              ],
            ),
            if (c['status']?['error'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${c['status']['error']}'),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: c['enabled'] == false
                      ? null
                      : () => setState(() {
                          _cameraId = c['id'] as int;
                          _tab = 0;
                        }),
                  icon: const Icon(Icons.live_tv),
                  label: const Text('Xem trực tiếp'),
                ),
                if (_api.canConfigure)
                  TextButton.icon(
                    onPressed: _stale
                        ? null
                        : () => _open(GuardCameraEditor(api: _api, camera: c)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Chỉnh sửa'),
                  ),
                if (widget.eye != null && _status?['device_id'] is String)
                  TextButton.icon(
                    onPressed: _stale
                        ? null
                        : () => _open(
                            PiCameraPage(
                              eye: widget.eye!,
                              guard: _api,
                              deviceId: _status!['device_id'],
                              camera: c,
                            ),
                          ),
                    icon: const Icon(Icons.open_with),
                    label: const Text('Liên kết / điều khiển PTZ'),
                  ),
              ],
            ),
          ],
        ),
      ),
  ];

  List<Widget> _settings() {
    final vision = _status?['vision'] as Map? ?? {};
    return [
      _heading(
        'Cài đặt',
        '${_api.currentUser?['full_name'] ?? _api.currentUser?['username'] ?? 'Tài khoản'} · ${_api.currentUser?['role'] ?? ''}',
      ),
      if (widget.eye != null)
        GuardPanel(
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Người tham gia'),
            subtitle: const Text(
              'Đăng ký, đồng ý và quản lý đối chiếu khuôn mặt',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(PeoplePage(eye: widget.eye!)),
          ),
        ),
      if (!_api.canConfigure)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Tài khoản chỉ có quyền xem. OWNER/ADMIN mới được thay đổi cấu hình.',
          ),
        ),
      GuardPanel(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Địa chỉ khẩn cấp'),
              subtitle: Text(
                _status?['location_configured'] == true
                    ? 'Đã có địa chỉ'
                    : 'Chưa có địa chỉ để đọc khi gọi',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(EmergencyLocationPage(api: _api)),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('Danh bạ khẩn cấp'),
              subtitle: Text(
                '${_status?['family_contacts'] ?? '—'} người thân · ${_status?['fire_dept_contacts'] ?? '—'} PCCC/bảo vệ',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(EmergencyContactsPage(api: _api)),
            ),
            const Divider(),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('Cuộc gọi do Edge Box quản lý'),
              subtitle: Text(
                'App không cung cấp gọi thử hoặc chỉnh quy tắc gọi PCCC. Cấu hình tự động hiện có trên Pi vẫn áp dụng.',
              ),
            ),
          ],
        ),
      ),
      GuardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tình trạng dịch vụ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Gemini: ${_status?['gemini_configured'] == true ? 'Đã cấu hình' : 'Chưa cấu hình'}',
            ),
            Text('Model: ${_status?['gemini_model'] ?? '—'}'),
            const Divider(),
            Text('Cuộc gọi: ${_status?['call_provider'] ?? '—'}'),
            Text(
              'Stringee: ${_status?['stringee_configured'] == true ? 'Đã cấu hình' : 'Chưa đủ cấu hình'}',
            ),
            if ((_status?['stringee_missing'] as List? ?? []).isNotEmpty)
              Text(
                'Cần bổ sung trên Pi: ${(_status!['stringee_missing'] as List).join(', ')}',
              ),
            if (_status?['call_provider'] == 'mock')
              const Text('Đang giả lập; không gọi điện thật.'),
          ],
        ),
      ),
      GuardPanel(
        child: ExpansionTile(
          key: const PageStorageKey('fireguard_pi_detection_tile'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Nhận diện trên Pi'),
          children: [
            ListTile(
              title: const Text('Nguồn phát hiện'),
              subtitle: Text('${_status?['detection_source'] ?? '—'}'),
            ),
            ListTile(
              title: const Text('Model lửa/khói'),
              subtitle: Text('${vision['model'] ?? '—'}'),
            ),
            ListTile(
              title: const Text('Model người'),
              subtitle: Text('${vision['person_model'] ?? '—'}'),
            ),
            if (vision['error'] != null)
              ListTile(title: Text('${vision['error']}')),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Chọn model, ngưỡng nhận diện và cấu hình nâng cao tại trang web FireGuard.',
              ),
            ),
            SelectionArea(child: Text('${_api.baseUrl}/ui/#settings')),
            const SizedBox(height: 12),
          ],
        ),
      ),
      Text(_api.baseUrl, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      const Text(
        'FireEye cung cấp tài khoản, PTZ và khuôn mặt. FireGuard giám sát cháy và xử lý sự cố. Cảnh báo trong app chỉ hoạt động khi app đang mở.',
      ),
    ];
  }

  Widget _readiness() {
    final issues = <String>[
      if (_stale) 'Chưa xác nhận được trạng thái mới',
      if (!_stale &&
          !_cameras.any(
            (c) =>
                c['enabled'] != false &&
                c['status']?['online'] == true &&
                c['detect_enabled'] != false &&
                (c['status']?['ai_fps'] as num? ?? 0) > 0,
          ))
        'Chưa có camera nhận diện đang hoạt động',
      if (_status?['vision']?['detector'] == 'mock') 'Nhận diện đang giả lập',
      if (_status?['location_configured'] != true) 'Chưa có địa chỉ khẩn cấp',
      if ((_status?['family_contacts'] as num? ?? 0) +
              (_status?['fire_dept_contacts'] as num? ?? 0) ==
          0)
        'Chưa có người nhận cuộc gọi',
      if (_status?['call_provider'] != 'stringee') 'Cuộc gọi đang giả lập',
      if (_status?['call_provider'] == 'stringee' &&
          _status?['stringee_configured'] != true)
        'Dịch vụ gọi chưa đủ cấu hình',
    ];
    final hasIssues = issues.isNotEmpty;
    return GuardPanel(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('fireguard_readiness_tile'),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: false,
          leading: Icon(
            hasIssues
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: hasIssues ? Colors.orange.shade800 : Colors.teal,
          ),
          title: Text(
            hasIssues
                ? 'Có ${issues.length} mục cần kiểm tra'
                : 'Đã đủ cấu hình cơ bản',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: hasIssues ? Colors.orange.shade900 : Colors.teal.shade900,
            ),
          ),
          subtitle: Text(
            hasIssues ? 'Nhấn để xem chi tiết' : 'Hệ thống sẵn sàng giám sát',
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            const SizedBox(height: 8),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(issue)),
                  ],
                ),
              ),
            if (!hasIssues)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Cần nghiệm thu camera, nhận diện và cuộc gọi trên thiết bị thật.',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Thông báo trong app tạm dừng khi khóa màn hình hoặc chuyển app. Pi vẫn xử lý theo cấu hình riêng.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasIssues) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _tab = 3),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Hoàn tất cấu hình'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('IGNIVO · FireGuard'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (v) => setState(() => _tab = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Tổng quan',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications_active),
          label: 'Sự kiện',
        ),
        NavigationDestination(
          icon: Icon(Icons.videocam_outlined),
          selectedIcon: Icon(Icons.videocam),
          label: 'Camera',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Cài đặt',
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_coordinator.feedbackError != null)
            MaterialBanner(
              content: Text(_coordinator.feedbackError!),
              actions: [
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Kiểm tra lại'),
                ),
              ],
            ),
          if (_activeIncident != null)
            PulsingAlertWrapper(
              active: _coordinator.level == AlertLevel.urgent && !_coordinator.isSilenced,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  ListTile(
                    leading: Icon(
                      _coordinator.level == AlertLevel.urgent &&
                              !_coordinator.isSilenced
                          ? Icons.warning_rounded
                          : Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text('Sự cố đang mở #${_activeIncident!['id']}'),
                    subtitle: Text(
                      '${IncidentPresentationHelper.cameraName(_activeIncident!)} · ${IncidentPresentationHelper.areaText(_activeIncident!)} · ${_activeIncident!['status'] == 'ai_dismissed' ? 'AI bổ sung nhận định không phải cháy; cần kiểm tra bằng chứng' : incidentStatusLabel(_activeIncident!['status'])}${_stale ? ' · Dữ liệu cũ' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openIncident(_activeIncident!['id'] as int),
                  ),
                  if (_coordinator.level == AlertLevel.urgent)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        children: [
                          if (!_coordinator.isSilenced)
                            Expanded(
                              child: FilledButton.tonalIcon(
                                key: const Key(
                                  'dashboard-silence-alarm-button',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.amber.shade200,
                                  foregroundColor: Colors.brown.shade900,
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  _coordinator.silenceAlarm();
                                },
                                icon: const Icon(Icons.volume_off, size: 18),
                                label: const Text('Tắt còi trên máy'),
                              ),
                            )
                          else ...[
                            Icon(
                              Icons.volume_mute,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Đã tắt chuông trên máy này',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _coordinator.resumeAlarm,
                              child: const Text('Bật lại'),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      key: PageStorageKey('guard-tab-$_tab'),
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _realtime.state == FireguardConnection.connected
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                              size: 18,
                              color:
                                  _realtime.state ==
                                      FireguardConnection.connected
                                  ? Colors.teal
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _connectionLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stale
                              ? (_updated == null
                                    ? 'Chưa cập nhật được trạng thái'
                                    : 'Chưa cập nhật được trạng thái · lần cuối ${TimeOfDay.fromDateTime(_updated!).format(context)}')
                              : (_updated == null
                                    ? 'Chưa cập nhật được trạng thái'
                                    : 'Cập nhật ${TimeOfDay.fromDateTime(_updated!).format(context)} · mỗi 5 giây'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        if (_error != null)
                          GuardPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dữ liệu có thể đã cũ. $_error',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                if (_api.authToken == null)
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Quay lại đăng nhập thiết bị',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ...switch (_tab) {
                          1 => _incidentList(),
                          2 => _cameraList(),
                          3 => _settings(),
                          _ => _live(),
                        },
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
