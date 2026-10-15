import 'dart:async';
import 'package:flutter/foundation.dart';
import 'alert_feedback_adapter.dart';
import 'fireguard_api_service.dart';
import 'fireguard_realtime_service.dart';

enum AlertLevel {
  none,
  warning,
  urgent,
}

class AlertIncidentState {
  const AlertIncidentState({
    required this.incidentId,
    this.status,
    this.severity,
    this.isSimulation = false,
    this.cameraName,
    this.area,
    required this.updatedAt,
  });

  final int incidentId;
  final String? status;
  final String? severity;
  final bool isSimulation;
  final String? cameraName;
  final String? area;
  final DateTime updatedAt;
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
  }) : feedback = feedbackAdapter ?? SystemAlertFeedbackAdapter() {
    _init();
  }

  final FireguardApiService api;
  final FireguardRealtimeService realtime;
  final AlertFeedbackAdapter feedback;
  final Duration sirenWatchdogDuration;

  StreamSubscription<FireguardEvent>? _eventSub;
  StreamSubscription<void>? _sessionSub;
  Timer? _watchdogTimer;

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
      if (_simulationAudible && _currentIncident != null && _currentIncident!.isSimulation) {
        final isUrgent = _currentIncident!.severity == 'critical' || _currentIncident!.severity == 'high';
        if (isUrgent) {
          _level = AlertLevel.urgent;
          _isSilenced = false;
          feedback.startAlarmSiren();
          _startWatchdog();
        } else {
          _level = AlertLevel.warning;
          _isSilenced = false;
          feedback.playWarningChime();
        }
      } else if (!_simulationAudible && _currentIncident != null && _currentIncident!.isSimulation) {
        silenceAlarm();
      }
      notifyListeners();
    }
  }

  final Set<String> _processedTransitions = <String>{};
  final Set<String> _silencedLevels = <String>{};

  void _init() {
    _eventSub = realtime.events.listen(_handleEvent);
    _sessionSub = api.sessionChanges.listen((_) => reset());
  }

  void _handleEvent(FireguardEvent event) {
    final data = event.data;
    final incidentId = event.incidentId;
    if (incidentId == null) return;

    final status = data['status']?.toString();
    final severity = data['severity']?.toString();
    final isSimulation = data['is_simulation'] == true;
    final cameraName = data['camera_name']?.toString();
    final area = data['area']?.toString();

    final systemId = api.baseUrl;
    final transitionKey = '$systemId:$incidentId:$status:$severity';

    // Sự cố đã kết thúc / nhận xử lý / báo nhầm
    if (status == 'resolved' || status == 'closed' || status == 'false_alarm') {
      stopAlert(incidentId: incidentId);
      return;
    }

    if (_processedTransitions.contains(transitionKey)) {
      return;
    }
    _processedTransitions.add(transitionKey);

    _currentIncident = AlertIncidentState(
      incidentId: incidentId,
      status: status,
      severity: severity,
      isSimulation: isSimulation,
      cameraName: cameraName,
      area: area,
      updatedAt: DateTime.now(),
    );

    // 1. Kiểm tra sự cố mô phỏng: mặc định không phát còi trừ khi người dùng chủ động bật
    if (isSimulation && !_simulationAudible) {
      _level = AlertLevel.warning;
      _isSilenced = true;
      notifyListeners();
      return;
    }

    // 2. Phân cấp mức độ cảnh báo
    final isUrgent = severity == 'critical' || severity == 'high';
    final targetLevel = isUrgent ? AlertLevel.urgent : AlertLevel.warning;

    final silenceKey = '$systemId:$incidentId:$targetLevel';
    final alreadySilenced = _silencedLevels.contains(silenceKey);

    if (targetLevel == AlertLevel.urgent) {
      _level = AlertLevel.urgent;
      if (!alreadySilenced) {
        _isSilenced = false;
        feedback.startAlarmSiren();
        _startWatchdog();
      } else {
        _isSilenced = true;
      }
    } else {
      // Mức warning (chime một lần, không kích hoạt còi lặp)
      if (_level != AlertLevel.urgent) {
        _level = AlertLevel.warning;
        if (!alreadySilenced) {
          _isSilenced = false;
          feedback.playWarningChime();
        } else {
          _isSilenced = true;
        }
      }
    }

    notifyListeners();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(sirenWatchdogDuration, () {
      if (_level == AlertLevel.urgent && !_isSilenced) {
        silenceAlarm();
      }
    });
  }

  /// Tắt còi trên thiết bị này (Silence) - Không gửi API ACK/Resolve, không can thiệp backend
  void silenceAlarm() {
    if (_currentIncident != null) {
      final silenceKey = '${api.baseUrl}:${_currentIncident!.incidentId}:$_level';
      _silencedLevels.add(silenceKey);
    }
    _isSilenced = true;
    _watchdogTimer?.cancel();
    feedback.stopAlarmSiren();
    feedback.cancelVibration();
    notifyListeners();
  }

  /// Bật lại còi nếu người dùng muốn nghe lại
  void resumeAlarm() {
    if (_level == AlertLevel.urgent && _currentIncident != null) {
      final silenceKey = '${api.baseUrl}:${_currentIncident!.incidentId}:$_level';
      _silencedLevels.remove(silenceKey);
      _isSilenced = false;
      feedback.startAlarmSiren();
      _startWatchdog();
      notifyListeners();
    }
  }

  /// Dừng hoàn toàn tín hiệu cảnh báo khi sự cố đã đóng/nhận xử lý
  void stopAlert({int? incidentId}) {
    if (incidentId != null && _currentIncident?.incidentId != incidentId) {
      return;
    }
    _level = AlertLevel.none;
    _isSilenced = false;
    _currentIncident = null;
    _watchdogTimer?.cancel();
    feedback.stopAlarmSiren();
    feedback.cancelVibration();
    notifyListeners();
  }

  /// Đồng bộ trạng thái khi reconnect hoặc kiểm tra ban đầu
  void syncActiveIncidents(List<Map<String, dynamic>> activeIncidents) {
    if (activeIncidents.isEmpty) {
      stopAlert();
      return;
    }

    // Ưu tiên sự cố mức khẩn cấp nhất (critical/high)
    final topIncident = activeIncidents.firstWhere(
      (inc) => inc['severity'] == 'critical' || inc['severity'] == 'high',
      orElse: () => activeIncidents.first,
    );

    final event = FireguardEvent('incident.updated', topIncident);
    _handleEvent(event);
  }

  /// Reset toàn bộ khi đổi Pi hoặc logout
  void reset() {
    stopAlert();
    _processedTransitions.clear();
    _silencedLevels.clear();
    _currentIncident = null;
    _level = AlertLevel.none;
    _isSilenced = false;
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
