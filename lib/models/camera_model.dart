import 'package:cloud_firestore/cloud_firestore.dart';

class CameraModel {
  const CameraModel({
    required this.id,
    required this.systemId,
    required this.edgeBoxId,
    required this.name,
    required this.model,
    required this.streamId,
    this.online = true,
    this.aiMonitored = true,
    this.supportsPtz = false,
    this.supportsMic = false,
    this.supportsPlayback = false,
    this.safetyStatus = 'NORMAL',
    this.snapshotUrl,
  });

  final String id;
  final String systemId;
  final String edgeBoxId;

  final String name;
  final String model;

  final String streamId;

  final bool online;
  final bool aiMonitored;

  final bool supportsPtz;
  final bool supportsMic;
  final bool supportsPlayback;

  final String safetyStatus;

  final String? snapshotUrl;

  // Backwards compatibility getter
  String get zoneName => name;
  String get lastSnapshotUrl => snapshotUrl ?? '';

  factory CameraModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document, {
        String? systemId,
      }) {
    final data = document.data() ?? {};

    final resolvedSystemId = systemId ??
        document.reference.parent.parent?.id ??
        '';

    return CameraModel(
      id: document.id,
      systemId: resolvedSystemId,
      edgeBoxId: data['edgeBoxId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'IP Camera',
      model: data['model']?.toString() ?? 'IP Cam',
      streamId: data['streamId']?.toString() ?? document.id,
      online: data['online'] != false,
      aiMonitored: data['aiMonitored'] != false,
      supportsPtz: data['supportsPtz'] == true,
      supportsMic: data['supportsMic'] == true,
      supportsPlayback: data['supportsPlayback'] == true,
      safetyStatus: data['safetyStatus']?.toString() ?? 'NORMAL',
      snapshotUrl: data['snapshotUrl']?.toString() ?? data['lastSnapshotUrl']?.toString(),
    );
  }
}
