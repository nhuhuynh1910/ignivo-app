import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'system_session_manager.dart';

/// Đại diện cho cảnh báo sự cố khẩn cấp từ một hệ thống (đặc biệt là hệ thống inactive)
class CrossSystemIncidentAlert {
  const CrossSystemIncidentAlert({
    required this.systemId,
    required this.systemName,
    required this.incidentId,
    this.cameraId,
    required this.severity,
    required this.title,
    required this.timestamp,
  });

  final String systemId;
  final String systemName;
  final int incidentId;
  final int? cameraId;
  final String severity;
  final String title;
  final DateTime timestamp;

  @override
  String toString() =>
      'CrossSystemIncidentAlert(system: $systemName ($systemId), incident #$incidentId, sev: $severity)';
}

/// Điều phối giám sát đa hệ thống theo cơ chế phân tầng (Tiered Monitoring)
/// Hệ thống Active được giám sát đầy đủ theo IgnivoShell & MonitoringController.
/// Các hệ thống Inactive được kiểm tra nhịp tim (lightweight heartbeat) định kỳ.
class MultiSystemMonitoringCoordinator extends ChangeNotifier {
  MultiSystemMonitoringCoordinator({
    required this.sessionManager,
    Duration? pollInterval,
    Duration? baseJitter,
  })  : _pollInterval = pollInterval ?? const Duration(seconds: 15),
        _baseJitter = baseJitter ?? const Duration(seconds: 2);

  final SystemSessionManager sessionManager;
  final Duration _pollInterval;
  final Duration _baseJitter;

  Timer? _pollingTimer;
  bool _isRunning = false;
  bool _isPolling = false;

  final StreamController<CrossSystemIncidentAlert> _alertController =
      StreamController<CrossSystemIncidentAlert>.broadcast();

  /// Stream cảnh báo từ hệ thống khác
  Stream<CrossSystemIncidentAlert> get onCrossSystemAlert =>
      _alertController.stream;

  /// Trạng thái kết nối của từng hệ thống (systemId -> reachable)
  final Map<String, bool> _systemHealth = {};
  Map<String, bool> get systemHealth => Map.unmodifiable(_systemHealth);

  /// Tập hợp các incident IDs đã gửi cảnh báo để tránh spam toast/banner (systemId:incidentId)
  final Set<String> _announcedIncidentKeys = {};

  /// Danh sách sự cố chưa đóng của từng hệ thống (systemId -> List)
  final Map<String, List<Map<String, dynamic>>> _inactiveIncidents = {};
  Map<String, List<Map<String, dynamic>>> get inactiveIncidents =>
      Map.unmodifiable(_inactiveIncidents);

  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _scheduleNextPoll();
  }

  void stop() {
    _isRunning = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void pause() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void resume() {
    if (_isRunning && _pollingTimer == null) {
      _scheduleNextPoll();
    }
  }

  void _scheduleNextPoll() {
    _pollingTimer?.cancel();
    if (!_isRunning) return;

    // Thêm jitter ngẫu nhiên từ 0 đến baseJitter để tránh request đồng thời
    final randomMs = Random().nextInt(_baseJitter.inMilliseconds + 1);
    final delay = _pollInterval + Duration(milliseconds: randomMs);

    _pollingTimer = Timer(delay, () async {
      await pollInactiveSystems();
      if (_isRunning) {
        _scheduleNextPoll();
      }
    });
  }

  /// Thực hiện kiểm tra nhanh các hệ thống đang ở chế độ Inactive
  Future<void> pollInactiveSystems() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      final activeId = sessionManager.activeSystemId;
      final systems = sessionManager.systems;

      for (final system in systems) {
        // Bỏ qua hệ thống active vì đã được MonitoringController trong IgnivoShell theo dõi 5s/lần
        if (system.systemId == activeId) continue;

        final controller = sessionManager.getController(system.systemId);
        if (controller == null) continue;

        try {
          // Lấy danh sách sự cố đang mở
          final incidents = await controller.api
              .getIncidents(limit: 5)
              .timeout(const Duration(seconds: 6));

          _systemHealth[system.systemId] = true;

          final unclosed = incidents.where((inc) {
            final st = inc['status']?.toString();
            return st != 'resolved' && st != 'false_alarm';
          }).toList();

          _inactiveIncidents[system.systemId] = unclosed;

          // Kiểm tra xem có sự cố mới cần cảnh báo không
          for (final inc in unclosed) {
            final id = inc['id'] ?? inc['incident_id'];
            if (id == null) continue;

            final intId = id is int ? id : int.tryParse(id.toString()) ?? 0;
            final key = '${system.systemId}:$intId';

            if (!_announcedIncidentKeys.contains(key)) {
              _announcedIncidentKeys.add(key);

              final sev = inc['severity']?.toString() ?? 'warning';
              final title = inc['title']?.toString() ??
                  'Phát hiện sự cố bất thường #$intId';
              final camIdRaw = inc['camera_id'];
              final camId = camIdRaw is int
                  ? camIdRaw
                  : int.tryParse(camIdRaw?.toString() ?? '');

              final alert = CrossSystemIncidentAlert(
                systemId: system.systemId,
                systemName: system.systemName,
                incidentId: intId,
                cameraId: camId,
                severity: sev,
                title: title,
                timestamp: DateTime.now(),
              );

              _alertController.add(alert);
            }
          }
        } catch (e) {
          // Ghi nhận lỗi kết nối nhưng không làm sập vòng lặp
          _systemHealth[system.systemId] = false;
          debugPrint(
            'Poll inactive system [${system.systemName} (${system.systemId})] error: $e',
          );
        }
      }

      notifyListeners();
    } finally {
      _isPolling = false;
    }
  }

  /// Đánh dấu đã xem sự cố để không cảnh báo lại
  void dismissAlert(String systemId, int incidentId) {
    _announcedIncidentKeys.add('$systemId:$incidentId');
  }

  /// Đặt lại danh sách cảnh báo đã gửi
  void clearAnnounced() {
    _announcedIncidentKeys.clear();
  }

  @override
  void dispose() {
    stop();
    _alertController.close();
    super.dispose();
  }
}
