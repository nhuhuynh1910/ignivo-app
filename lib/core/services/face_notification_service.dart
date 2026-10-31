import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fireeye_api_service.dart';

class FaceNotificationEvent {
  const FaceNotificationEvent({
    required this.id,
    required this.eventType,
    required this.message,
    this.name,
    this.snapshotPath,
    required this.createdAt,
    this.isRead = false,
  });

  final int id;
  final String eventType;
  final String message;
  final String? name;
  final String? snapshotPath;
  final String createdAt;
  final bool isRead;

  bool get isKnownPerson => eventType == 'KNOWN_PERSON';
  bool get isUnknownPerson => eventType == 'UNKNOWN_PERSON';

  factory FaceNotificationEvent.fromJson(Map<String, dynamic> json) {
    return FaceNotificationEvent(
      id: json['id'] as int? ?? 0,
      eventType: json['event_type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      name: json['name']?.toString(),
      snapshotPath: json['snapshot_path']?.toString(),
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

  final StreamController<FaceNotificationEvent> _eventController =
      StreamController<FaceNotificationEvent>.broadcast();
  Stream<FaceNotificationEvent> get onFaceEvent => _eventController.stream;

  final Set<int> _seenEventIds = <int>{};
  Timer? _pollTimer;
  FireeyeApiService? _eye;

  Future<void> initialize({FireeyeApiService? eye}) async {
    final prefs = await SharedPreferences.getInstance();
    _notifyKnown = prefs.getBool(keyNotifyKnown) ?? true;
    _notifyUnknown = prefs.getBool(keyNotifyUnknown) ?? true;
    _initialized = true;
    notifyListeners();

    if (eye != null) {
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

  void startListening(FireeyeApiService eye) {
    _eye = eye;
    _pollTimer?.cancel();

    // Query on start to record existing event IDs so we don't spam old notifications
    _pollEvents(isInitial: true);

    // Poll for new face events periodically
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollEvents(isInitial: false);
    });
  }

  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
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

        if (_seenEventIds.add(event.id)) {
          // Check preferences
          if (event.isKnownPerson && !_notifyKnown) {
            continue;
          }
          if (event.isUnknownPerson && !_notifyUnknown) {
            continue;
          }

          if (event.isKnownPerson || event.isUnknownPerson) {
            _eventController.add(event);
          }
        }
      }
    } catch (_) {}
  }

  /// Cho phép phát sự kiện thủ công (ví dụ từ WebSocket hoặc bài kiểm tra)
  void dispatchEvent(FaceNotificationEvent event) {
    if (event.isKnownPerson && !_notifyKnown) return;
    if (event.isUnknownPerson && !_notifyUnknown) return;
    _eventController.add(event);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _eventController.close();
    super.dispose();
  }
}
