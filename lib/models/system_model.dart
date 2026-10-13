import 'package:cloud_firestore/cloud_firestore.dart';

class IgnivoSystem {
  const IgnivoSystem({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.locationName,
    required this.edgeBoxId,
    required this.edgeCode,
    this.cameraCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String locationName;
  final String edgeBoxId;
  final String edgeCode;
  final int cameraCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory IgnivoSystem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? {};

    final code = data['edgeCode']?.toString() ?? data['edgeBoxId']?.toString() ?? '';

    return IgnivoSystem(
      id: document.id,
      ownerId: data['ownerId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'IGNIVO Edge Box',
      locationName: data['locationName']?.toString() ?? '',
      edgeBoxId: data['edgeBoxId']?.toString() ?? code,
      edgeCode: code,
      cameraCount: (data['cameraCount'] as num?)?.toInt() ?? 0,
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: _timestampToDateTime(data['updatedAt']),
    );
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
