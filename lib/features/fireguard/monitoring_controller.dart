import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/fireguard_realtime_service.dart';
import '../../core/services/incident_alert_coordinator.dart';

class MonitoringController extends ChangeNotifier {
  MonitoringController({
    required this.api,
    FireguardRealtimeService? realtime,
    IncidentAlertCoordinator? coordinator,
  })  : realtime = realtime ?? FireguardRealtimeService(api),
        coordinator = coordinator ??
            IncidentAlertCoordinator(
              api: api,
              realtime: realtime ?? FireguardRealtimeService(api),
            ),
        _ownsRealtime = realtime == null,
        _ownsCoordinator = coordinator == null;

  final FireguardApiService api;
  final FireguardRealtimeService realtime;
  final IncidentAlertCoordinator coordinator;
  final bool _ownsRealtime;
  final bool _ownsCoordinator;

  List<Map<String, dynamic>> _cameras = [];
  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic>? _activeIncident;
  Map<String, dynamic>? _status;
  DateTime? _updated;
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  bool _fresh = false;
  bool _foreground = true;
  bool _resumeAfterRefresh = false;
  int _eventRevision = 0;

  int? _detailedIncidentId;
  Map<String, dynamic>? _detailedIncident;
  List<Map<String, dynamic>> _detailedCallLogs = [];

  Timer? _pollingTimer;
  StreamSubscription<FireguardEvent>? _eventSub;
  bool _refreshQueued = false;
  final Set<int> _announced = {};

  List<Map<String, dynamic>> get cameras => _cameras;
  List<Map<String, dynamic>> get incidents => _incidents;
  Map<String, dynamic>? get activeIncident => _activeIncident;
  Map<String, dynamic>? get status => _status;
  DateTime? get updated => _updated;
  bool get loading => _loading;
  bool get fetching => _fetching;
  String? get error => _error;
  bool get fresh => _fresh;
  bool get stale => _error != null || !_fresh;
  int? get detailedIncidentId => _detailedIncidentId;
  Map<String, dynamic>? get detailedIncident => _detailedIncident;
  List<Map<String, dynamic>> get detailedCallLogs => _detailedCallLogs;
  Set<int> get announcedIncidentIds => _announced;

  bool get isWsConnected => realtime.state == FireguardConnection.connected;

  String get connectionLabel => switch (realtime.state) {
        FireguardConnection.connected => 'Đã kết nối cảnh báo trực tiếp',
        FireguardConnection.connecting => 'Đang kết nối cảnh báo…',
        FireguardConnection.reconnecting => 'Mất kết nối cảnh báo — đang thử lại',
        FireguardConnection.expired => 'Phiên hết hạn — cần đăng nhập lại',
        FireguardConnection.stopped => 'Cảnh báo trực tiếp tạm dừng',
      };

  void start() {
    if (_pollingTimer != null) return;

    realtime.addListener(_onRealtimeChanged);
    coordinator.addListener(_onCoordinatorChanged);
    _eventSub = realtime.events.listen(_onEvent);
    realtime.start();

    // Initial fetch
    refresh();

    // Single business polling timer every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_foreground && api.authToken != null) {
        refresh();
      }
    });
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _eventSub?.cancel();
    _eventSub = null;
    realtime.removeListener(_onRealtimeChanged);
    coordinator.removeListener(_onCoordinatorChanged);
    realtime.stop();
  }

  void pause() {
    _foreground = false;
    _eventRevision++;
    coordinator.pauseFeedback();
    _fresh = false;
    realtime.stop();
    notifyListeners();
  }

  void resume() {
    _foreground = true;
    _resumeAfterRefresh = true;
    realtime.start();
    refresh();
    notifyListeners();
  }

  void _onRealtimeChanged() {
    notifyListeners();
    if (realtime.state == FireguardConnection.connected) {
      refresh();
    }
  }

  void _onCoordinatorChanged() {
    notifyListeners();
  }

  void _onEvent(FireguardEvent event) {
    if (!_foreground) return;
    _eventRevision++;

    if (event.name == 'incident.created' && event.incidentId != null) {
      _announced.add(event.incidentId!);
    }

    if (event.incidentId != null && event.incidentId == _detailedIncidentId) {
      fetchDetail(_detailedIncidentId!);
    }

    refresh();
  }

  Future<void> refresh() async {
    if (_fetching) {
      _refreshQueued = true;
      return;
    }
    _fetching = true;
    _refreshQueued = false;

    final revision = _eventRevision;
    final session = api.sessionRevision;
    final origin = api.baseUrl;

    try {
      await api.getCurrentUser();
      final sysStatus = await api.getSystemStatus();
      if (sysStatus == null) {
        throw FireguardException(api.lastError ?? 'Không tải được trạng thái hệ thống.');
      }
      final camList = await api.getCameras();
      final incList = await api.getIncidents();
      final active = await api.getActiveIncident();

      final syncList = <Map<String, dynamic>>[?active, ...incList];

      // Limited lists cannot confirm that a previously tracked incident ended.
      // Fetch missing IDs explicitly to recover ACK/close events missed offline.
      final listedIds = syncList.map((i) => i['id']).toSet();
      for (final id in coordinator.trackedIncidentIds) {
        if (!listedIds.contains(id)) {
          final detail = await api.getIncidentDetail(id);
          if (detail != null) syncList.add(detail);
        }
      }

      // Check if viewing details of a registered incident
      if (_detailedIncidentId != null) {
        try {
          final detail = await api.getIncidentDetail(_detailedIncidentId!);
          if (detail != null) {
            _detailedIncident = detail;
          }
        } catch (_) {}
      }

      if (_foreground &&
          revision == _eventRevision &&
          session == api.sessionRevision &&
          origin == api.baseUrl) {
        coordinator.syncActiveIncidents(syncList);

        if (_resumeAfterRefresh) {
          _resumeAfterRefresh = false;
          coordinator.resumeFeedback();
        }

        _status = sysStatus;
        _cameras = camList;
        _incidents = incList;
        _activeIncident = active;
        _error = null;
        _updated = DateTime.now();
        _fresh = true;
        notifyListeners();
      }
    } catch (e) {
      _error = '$e';
      notifyListeners();
    } finally {
      _fetching = false;
      _loading = false;
      notifyListeners();

      if (_refreshQueued && _foreground && api.authToken != null) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  void registerDetailedIncident(int id) {
    _detailedIncidentId = id;
    fetchDetail(id);
  }

  void unregisterDetailedIncident(int id) {
    if (_detailedIncidentId == id) {
      _detailedIncidentId = null;
      _detailedIncident = null;
      _detailedCallLogs = [];
      notifyListeners();
    }
  }

  Future<void> fetchDetail(int id) async {
    try {
      final detail = await api.getIncidentDetail(id);
      if (_detailedIncidentId == id && detail != null) {
        _detailedIncident = detail;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    if (_ownsCoordinator) {
      coordinator.dispose();
    }
    if (_ownsRealtime) {
      realtime.dispose();
    }
    super.dispose();
  }
}
