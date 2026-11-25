import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fireeye_api_service.dart';
import 'fireguard_realtime_service.dart';

class FaceNotificationEvent {
  const FaceNotificationEvent({
    required this.id,
    required this.eventType,
    required this.message,
    this.name,
    this.snapshotPath,
    this.area,
    this.cameraId,
    this.personId,
    this.role,
    this.confidence,
    required this.createdAt,
    this.isRead = false,
  });

  final int id;
  final String eventType;
  final String message;
  final String? name;
  final String? snapshotPath;
  final String? area;
  final int? cameraId;
  final int? personId;
  final String? role;
  final double? confidence;
  final String createdAt;
  final bool isRead;

  bool get isKnownPerson => eventType == 'KNOWN_PERSON';
  bool get isUnknownPerson => eventType == 'UNKNOWN_PERSON';

  factory FaceNotificationEvent.fromJson(Map<String, dynamic> json) {
    return FaceNotificationEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventType: json['event_type']?.toString().toUpperCase() ?? '',
      message: json['message']?.toString() ?? '',
      name: json['person_name']?.toString() ?? json['name']?.toString(),
      snapshotPath:
          json['snapshot_url']?.toString() ?? json['snapshot_path']?.toString(),
      area: json['area']?.toString(),
      cameraId: (json['camera_id'] as num?)?.toInt(),
      personId: (json['person_id'] as num?)?.toInt(),
      role: json['role']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      createdAt: json['created_at']?.toString() ?? '',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
    );
  }
}

class FaceNotificationService extends ChangeNotifier {
  FaceNotificationService._();
  static final FaceNotificationService instance = FaceNotificationService._();

  static const String keyNotifyKnown = 'pref_face_notify_known';
  static const String keyNotifyUnknown = 'pref_face_notify_unknown';

  bool _notifyKnown = true;
  bool _notifyUnknown = true;
  bool _initialized = false;

  bool get notifyKnown => _notifyKnown;
  bool get notifyUnknown => _notifyUnknown;
  bool get isInitialized => _initialized;

  final StreamController<FaceNotificationEvent> _eventController =
      StreamController<FaceNotificationEvent>.broadcast();
  Stream<FaceNotificationEvent> get onFaceEvent => _eventController.stream;

  final Set<int> _seenEventIds = <int>{};
  Timer? _pollTimer;
  StreamSubscription<FireguardEvent>? _realtimeSub;
  FireeyeApiService? _eye;

  Future<void> initialize({
    FireeyeApiService? eye,
    FireguardRealtimeService? realtime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _notifyKnown = prefs.getBool(keyNotifyKnown) ?? true;
    _notifyUnknown = prefs.getBool(keyNotifyUnknown) ?? true;
    _initialized = true;
    notifyListeners();

    if (realtime != null) {
      bindRealtime(realtime);
    } else if (eye != null) {
      startListening(eye);
    }
  }

  Future<void> setNotifyKnown(bool value) async {
    _notifyKnown = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyNotifyKnown, value);
    notifyListeners();
  }

  Future<void> setNotifyUnknown(bool value) async {
    _notifyUnknown = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyNotifyUnknown, value);
    notifyListeners();
  }

  /// Lắng nghe trực tiếp sự kiện `face.detected` / `face.unknown` từ WebSocket FireGuard.
  void bindRealtime(FireguardRealtimeService realtime) {
    _pollTimer?.cancel();
    _pollTimer = null;
    _realtimeSub?.cancel();
    _realtimeSub = realtime.events
        .where((e) => e.isFaceEvent)
        .listen((e) => dispatchEvent(FaceNotificationEvent.fromJson(e.data)));
  }

  void startListening(FireeyeApiService eye) {
    _eye = eye;
    _pollTimer?.cancel();

    _pollEvents(isInitial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollEvents(isInitial: false);
    });
  }

  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  Future<void> _pollEvents({bool isInitial = false}) async {
    if (_eye == null) return;
    try {
      final events = await _eye!.getEvents();
      for (final raw in events) {
        final event = FaceNotificationEvent.fromJson(raw);
        if (event.id <= 0) continue;

        if (isInitial) {
          _seenEventIds.add(event.id);
          continue;
        }
        dispatchEvent(event);
      }
    } catch (_) {}
  }

  /// Phát sự kiện nhận diện khuôn mặt (từ WebSocket hoặc bài kiểm tra), có kiểm tra trùng lặp & tùy chọn.
  void dispatchEvent(FaceNotificationEvent event) {
    if (event.id > 0 && !_seenEventIds.add(event.id)) return;
    if (event.isKnownPerson && !_notifyKnown) return;
    if (event.isUnknownPerson && !_notifyUnknown) return;
    if (event.isKnownPerson || event.isUnknownPerson) {
      _eventController.add(event);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _realtimeSub?.cancel();
    _eventController.close();
    super.dispose();
  }
}
