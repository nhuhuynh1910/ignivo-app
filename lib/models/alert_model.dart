import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  const AlertModel({
    required this.id,
    required this.systemId,
    required this.cameraId,
    required this.cameraName,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.snapshotUrl,
    required this.eventId,
    required this.incidentSummary,
    required this.acknowledged,
    this.createdAt,
  });

  final String id;
  final String systemId;
  final String cameraId;
  final String cameraName;

  /// FIRE, SMOKE, ABNORMAL_EVENT, INTRUSION, SYSTEM
  final String type;

  /// NORMAL / SUSPICIOUS / ALERT / CRITICAL
  final String severity;

  final String title;
  final String message;

  final String snapshotUrl;
  final String eventId;
  final String incidentSummary;

  final bool acknowledged;

  final DateTime? createdAt;

  // Backwards compatibility getter
  String get systemName => 'IGNIVO System';
  String get zoneName => cameraName;

  factory AlertModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document, {
        required String systemId,
      }) {
    final data = document.data() ?? {};

    return AlertModel(
      id: document.id,
      systemId: systemId,
      cameraId: data['cameraId']?.toString() ?? '',
      cameraName: data['cameraName']?.toString() ?? data['zoneName']?.toString() ?? 'Camera',
      type: data['type']?.toString() ?? 'UNKNOWN',
      severity: data['severity']?.toString() ?? 'ALERT',
      title: data['title']?.toString() ?? 'Cảnh báo IGNIVO',
      message: data['message']?.toString() ?? '',
      snapshotUrl: data['snapshotUrl']?.toString() ?? '',
      eventId: data['eventId']?.toString() ?? '',
      incidentSummary: data['incidentSummary']?.toString() ?? data['message']?.toString() ?? '',
      acknowledged: data['acknowledged'] == true,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
