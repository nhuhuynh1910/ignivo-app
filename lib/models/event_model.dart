import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.systemId,
    required this.cameraId,
    required this.type,
    required this.severity,
    required this.status,
    required this.title,
    required this.summary,
    required this.snapshotUrl,
    required this.clipUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String systemId;
  final String cameraId;

  final String type;
  final String severity;
  final String status;

  final String title;
  final String summary;

  final String snapshotUrl;
  final String clipUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EventModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document, {
        required String systemId,
      }) {
    final data = document.data() ?? {};

    return EventModel(
      id: document.id,
      systemId: systemId,
      cameraId: data['cameraId']?.toString() ?? '',
      type: data['type']?.toString() ?? data['eventType']?.toString() ?? 'EVENT',
      severity: data['severity']?.toString() ?? 'ALERT',
      status: data['status']?.toString() ?? 'NEW',
      title: data['title']?.toString() ?? 'Sự kiện an ninh',
      summary: data['summary']?.toString() ?? data['incidentSummary']?.toString() ?? data['message']?.toString() ?? '',
      snapshotUrl: data['snapshotUrl']?.toString() ?? '',
      clipUrl: data['clipUrl']?.toString() ?? '',
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
