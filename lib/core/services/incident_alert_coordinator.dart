import 'dart:async';
import 'package:flutter/foundation.dart';
import 'alert_feedback_adapter.dart';
import 'fireguard_api_service.dart';
import 'fireguard_realtime_service.dart';

enum AlertLevel { none, warning, urgent }

class AlertIncidentState {
  const AlertIncidentState({
    required this.incidentId,
    this.status,
    this.severity,
    this.isSimulation = false,
    this.cameraName,
    this.area,
    required this.updatedAt,
    this.serverUpdatedAt,
  });

  final int incidentId;
  final String? status;
  final String? severity;
  final bool isSimulation;
  final String? cameraName;
  final String? area;
  final DateTime updatedAt;
  final DateTime? serverUpdatedAt;
}

/// Điều phối cảnh báo âm thanh và rung ở phạm vi phiên hệ thống IGNIVO.
/// Đảm bảo cảnh báo có quy tắc, không phát lặp khi reconnect, tách biệt thao tác
/// "Tắt còi trên điện thoại" khỏi thao tác nghiệp vụ "Nhận xử lý sự cố".
class IncidentAlertCoordinator extends ChangeNotifier {
  IncidentAlertCoordinator({
    required this.api,
    required this.realtime,
    AlertFeedbackAdapter? feedbackAdapter,
    this.sirenWatchdogDuration = const Duration(seconds: 60),
  }) : feedback = feedbackAdapter ?? SystemAlertFeedbackAdapter(),
       _lastBaseUrl = api.baseUrl,
       _lastSessionRevision = api.sessionRevision {
    _init();
  }

  final FireguardApiService api;
  final FireguardRealtimeService realtime;
  final AlertFeedbackAdapter feedback;
  final Duration sirenWatchdogDuration;

  String _lastBaseUrl;
  int _lastSessionRevision;

  StreamSubscription<FireguardEvent>? _eventSub;
  StreamSubscription<void>? _sessionSub;
  Timer? _watchdogTimer;

  bool _isBackground = false;

  AlertLevel _level = AlertLevel.none;
  AlertLevel get level => _level;

  AlertIncidentState? _currentIncident;
  AlertIncidentState? get currentIncident => _currentIncident;

  bool _isSilenced = false;
  bool get isSilenced => _isSilenced;

  bool _simulationAudible = false;
  bool get simulationAudible => _simulationAudible;
  set simulationAudible(bool value) {
    if (_simulationAudible != value) {
      _simulationAudible = value;
      _recalculateAlertState();
    }
  }

  final Map<int, AlertIncidentState> _activeIncidents =
      <int, AlertIncidentState>{};
  final Map<int, DateTime> _terminatedIncidents = <int, DateTime>{};
  final Map<int, String> _acknowledgedSeverities = <int, String>{};
  final Map<int, DateTime> _lastServerUpdates = <int, DateTime>{};
  final Set<int> _pendingAcknowledgements = <int>{};
  AlertIncidentState? _audibleIncident;
  List<int> get trackedIncidentIds =>
      {..._activeIncidents.keys, ..._pendingAcknowledgements}.toList();
  String? get feedbackError => feedback.lastError;
  final Set<String> _processedTransitions = <String>{};
  final Set<int> _silencedIncidentIds = <int>{};
  final Map<int, String> _silencedSeverities = <int, String>{};

  static const _terminalStatuses = {'resolved', 'closed', 'false_alarm'};

  void _init() {
    _eventSub = realtime.events.listen(_handleEvent);
    _sessionSub = api.sessionChanges.listen((_) {
      final baseUrlChanged = _lastBaseUrl != api.baseUrl;
      final revisionChanged = _lastSessionRevision != api.sessionRevision;
      final loggedOut = api.authToken == null;
      if (baseUrlChanged || revisionChanged || loggedOut) {
        _lastBaseUrl = api.baseUrl;
        _lastSessionRevision = api.sessionRevision;
        reset();
      }
    });
  }

  void _handleEvent(FireguardEvent event) {
    // Chỉ xử lý các sự kiện incident lifecycle; bỏ qua call.updated và sự kiện khác
    if (!event.name.startsWith('incident.')) {
      return;
    }
    final incidentId = event.incidentId;
    if (incidentId == null) return;

    _handleIncidentData(event.data, incidentId: incidentId);
  }

  void _handleIncidentData(
    Map<String, dynamic> data, {
    int? incidentId,
    bool isFromSync = false,
  }) {
    final id =
        incidentId ??
        (data['id'] is int ? data['id'] as int : int.tryParse('${data['id']}'));
    if (id == null) return;

    final status = data['status']?.toString();
    final severity = data['severity']?.toString();
    final isSimulation = data['is_simulation'] == true;
    final cameraName = data['camera_name']?.toString();
    final area = data['area']?.toString();

    DateTime? serverUpdatedAt;
    if (data['updated_at'] != null) {
      try {
        serverUpdatedAt = DateTime.parse(data['updated_at'].toString()).toUtc();
      } catch (_) {}
    }

    final existingIncident = _activeIncidents[id];

    // Chặn cập nhật cũ hơn từ server đến muộn (out-of-order)
    final lastServerUpdate = _lastServerUpdates[id];
    if (serverUpdatedAt != null && lastServerUpdate != null) {
      if (serverUpdatedAt.isBefore(lastServerUpdate)) {
        return;
      }
    }
    // Preserve the watermark even after ACK removes the audible incident.
    if (serverUpdatedAt != null) _lastServerUpdates[id] = serverUpdatedAt;

    // Sự cố đã kết thúc vĩnh viễn (resolved, false_alarm, closed)
    if (_terminalStatuses.contains(status)) {
      _terminatedIncidents[id] = serverUpdatedAt ?? DateTime.now().toUtc();
      _activeIncidents.remove(id);
      _acknowledgedSeverities.remove(id);
      _silencedIncidentIds.remove(id);
      _recalculateAlertState();
      return;
    }

    // Nếu sự cố đã kết thúc vĩnh viễn, sự kiện cũ không được mở lại
    if (_terminatedIncidents.containsKey(id)) {
      return;
    }

    // Xử lý trạng thái Acknowledged: dừng còi cho sự cố này
    if (status == 'acknowledged') {
      _pendingAcknowledgements.remove(id);
      _acknowledgedSeverities[id] = severity ?? 'high';
      _activeIncidents.remove(id);
      _recalculateAlertState();
      return;
    }

    // Nếu sự cố đã được ACK, sự kiện trùng lặp hoặc cùng mức độ không kích hoạt lại còi
    final ackSeverity = _acknowledgedSeverities[id];
    if (ackSeverity != null) {
      if (_pendingAcknowledgements.contains(id)) return;
      final isNewerTimestamp =
          serverUpdatedAt != null &&
          lastServerUpdate != null &&
          serverUpdatedAt.isAfter(lastServerUpdate);
      final isHigherSeverity =
          (ackSeverity == 'high' && severity == 'critical');
      if (!isHigherSeverity || !isNewerTimestamp) {
        return;
      }
      if (isHigherSeverity) {
        _acknowledgedSeverities.remove(id);
      }
    }

    final systemId = api.baseUrl;
    final transitionKey =
        '$systemId:$id:$status:$severity:${data['updated_at'] ?? ''}';
    if (!isFromSync && _processedTransitions.contains(transitionKey)) {
      return;
    }
    _processedTransitions.add(transitionKey);

    final isUrgent =
        (severity == 'critical' || severity == 'high') &&
        status != 'ai_dismissed';
    final targetLevel = isUrgent ? AlertLevel.urgent : AlertLevel.warning;

    // Quy tắc silence: im lặng cùng cấp; nếu tăng từ high lên critical thì cảnh báo lại
    final wasSilenced = _silencedIncidentIds.contains(id);
    final lastSilencedSev = _silencedSeverities[id];

    if (wasSilenced && lastSilencedSev == 'high' && severity == 'critical') {
      _silencedIncidentIds.remove(id);
      _silencedSeverities.remove(id);
    }

    _activeIncidents[id] = AlertIncidentState(
      incidentId: id,
      status: status,
      severity: severity,
      isSimulation: isSimulation,
      cameraName: cameraName,
      area: area,
      updatedAt: DateTime.now(),
      serverUpdatedAt: serverUpdatedAt,
    );

    // Chime warning khi có sự cố mới hoặc đổi severity sang warning
    if (targetLevel == AlertLevel.warning &&
        !_isBackground &&
        status != 'ai_dismissed' &&
        !_silencedIncidentIds.contains(id) &&
        (!isSimulation || _simulationAudible)) {
      if (existingIncident == null || existingIncident.severity != severity) {
        feedback.playWarningChime();
      }
    }

    if (!isFromSync) {
      _recalculateAlertState();
    }
  }

  void _recalculateAlertState() {
    _audibleIncident = null;
    if (_activeIncidents.isEmpty) {
      _currentIncident = null;
      _level = AlertLevel.none;
      _isSilenced = false;
      _watchdogTimer?.cancel();
      feedback.stopAlarmSiren();
      feedback.cancelVibration();
      notifyListeners();
      return;
    }

    // 1. Phân loại theo mức độ ưu tiên: lọc sự cố khẩn cấp (critical / high, loại trừ ai_dismissed)
    final urgentIncidents = _activeIncidents.values.where((inc) {
      return (inc.severity == 'critical' || inc.severity == 'high') &&
          inc.status != 'ai_dismissed' &&
          inc.status != 'acknowledged';
    }).toList();

    if (urgentIncidents.isNotEmpty) {
      final audibleUrgent = urgentIncidents.where((inc) {
        final isSilenced = _silencedIncidentIds.contains(inc.incidentId);
        final isMutedSim = inc.isSimulation && !_simulationAudible;
        return !isSilenced && !isMutedSim;
      }).toList();

      // Sắp xếp ưu tiên: mức độ trước (critical > high), sau đó trạng thái cần phát âm, sau đó thời gian mới nhất
      urgentIncidents.sort((a, b) {
        final aCritical = a.severity == 'critical';
        final bCritical = b.severity == 'critical';
        if (aCritical != bCritical) return aCritical ? -1 : 1;

        final aAudible = audibleUrgent.contains(a);
        final bAudible = audibleUrgent.contains(b);
        if (aAudible != bAudible) return aAudible ? -1 : 1;

        final aTime = a.serverUpdatedAt ?? a.updatedAt;
        final bTime = b.serverUpdatedAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });

      _currentIncident = urgentIncidents.first;
      _audibleIncident = urgentIncidents
          .where(audibleUrgent.contains)
          .firstOrNull;
      _level = AlertLevel.urgent;
      _isSilenced = audibleUrgent.isEmpty;

      if (audibleUrgent.isNotEmpty && !_isBackground) {
        if (!feedback.isSirenPlaying) {
          feedback.startAlarmSiren();
          _startWatchdog();
        }
      } else {
        _watchdogTimer?.cancel();
        feedback.stopAlarmSiren();
        feedback.cancelVibration();
      }
    } else {
      // Chỉ còn các sự cố warning (không tính ai_dismissed hay acknowledged)
      _watchdogTimer?.cancel();
      feedback.stopAlarmSiren();
      feedback.cancelVibration();

      final warningIncidents =
          _activeIncidents.values.where((inc) {
            return inc.status != 'ai_dismissed' && inc.status != 'acknowledged';
          }).toList()..sort((a, b) {
            final aTime = a.serverUpdatedAt ?? a.updatedAt;
            final bTime = b.serverUpdatedAt ?? b.updatedAt;
            return bTime.compareTo(aTime);
          });

      if (warningIncidents.isNotEmpty) {
        _currentIncident = warningIncidents.first;
        _level = AlertLevel.warning;
        _isSilenced = _silencedIncidentIds.contains(
          _currentIncident!.incidentId,
        );
      } else {
        _currentIncident = null;
        _level = AlertLevel.none;
        _isSilenced = false;
      }
    }

    notifyListeners();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(sirenWatchdogDuration, () {
      // Bound the entire audible session, including simultaneous incidents.
      for (final incident in _activeIncidents.values) {
        if (incident.severity == 'high' || incident.severity == 'critical') {
          _silencedIncidentIds.add(incident.incidentId);
          _silencedSeverities[incident.incidentId] = incident.severity!;
        }
      }
      _recalculateAlertState();
    });
  }

  /// Tắt còi trên thiết bị này (Silence) - Không gửi API ACK/Resolve, không can thiệp backend
  void silenceAlarm() {
    final target = _audibleIncident ?? _currentIncident;
    if (target != null) {
      _silencedIncidentIds.add(target.incidentId);
      _silencedSeverities[target.incidentId] = target.severity ?? '';
    }
    _recalculateAlertState();
  }

  /// Bật lại còi nếu người dùng muốn nghe lại
  void resumeAlarm() {
    if (_currentIncident != null) {
      _silencedIncidentIds.remove(_currentIncident!.incidentId);
      _silencedSeverities.remove(_currentIncident!.incidentId);
    }
    _recalculateAlertState();
  }

  /// Dừng hoàn toàn tín hiệu cảnh báo khi sự cố đã đóng/nhận xử lý
  void acknowledgeLocally(int id) {
    _pendingAcknowledgements.add(id);
    _acknowledgedSeverities[id] = _activeIncidents[id]?.severity ?? 'high';
    _activeIncidents.remove(id);
    _recalculateAlertState();
  }

  /// Dừng tín hiệu của sự cố đã đóng, không dùng cho ACK.
  void stopAlert({int? incidentId}) {
    if (incidentId != null) {
      _terminatedIncidents[incidentId] = DateTime.now().toUtc();
      _activeIncidents.remove(incidentId);
      _acknowledgedSeverities.remove(incidentId);
    } else {
      for (final id in _activeIncidents.keys) {
        _terminatedIncidents[id] = DateTime.now().toUtc();
      }
      _activeIncidents.clear();
      _acknowledgedSeverities.clear();
    }
    _recalculateAlertState();
  }

  /// Tạm dừng âm thanh khi app đi nền (foreground policy)
  void pauseFeedback() {
    _isBackground = true;
    _watchdogTimer?.cancel();
    feedback.stopAlarmSiren();
    feedback.cancelVibration();
  }

  /// Khôi phục âm thanh khi app trở lại foreground
  void resumeFeedback() {
    _isBackground = false;
    _recalculateAlertState();
  }

  /// Đồng bộ trạng thái khi reconnect hoặc kiểm tra ban đầu (không xóa sự cố vắng mặt do danh sách giới hạn)
  void syncActiveIncidents(List<Map<String, dynamic>> activeIncidents) {
    if (activeIncidents.isEmpty) {
      _recalculateAlertState();
      return;
    }

    for (final inc in activeIncidents) {
      final id = inc['id'] is int
          ? inc['id'] as int
          : int.tryParse('${inc['id']}');
      if (id != null) {
        _handleIncidentData(inc, incidentId: id, isFromSync: true);
      }
    }

    _recalculateAlertState();
  }

  /// Reset toàn bộ khi đổi Pi hoặc logout
  void reset() {
    _activeIncidents.clear();
    _terminatedIncidents.clear();
    _acknowledgedSeverities.clear();
    _lastServerUpdates.clear();
    _pendingAcknowledgements.clear();
    _audibleIncident = null;
    _processedTransitions.clear();
    _silencedIncidentIds.clear();
    _silencedSeverities.clear();
    _currentIncident = null;
    _level = AlertLevel.none;
    _isSilenced = false;
    _watchdogTimer?.cancel();
    feedback.stopAlarmSiren();
    feedback.cancelVibration();
    notifyListeners();
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _eventSub?.cancel();
    _sessionSub?.cancel();
    feedback.dispose();
    super.dispose();
  }
}
