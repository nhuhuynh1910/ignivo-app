import 'package:firebase_database/firebase_database.dart';
import '../../models/edge_live_status_model.dart';

class RealtimeDatabaseService {
  RealtimeDatabaseService({
    FirebaseDatabase? database,
  }) : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  /// Stream Edge Box status from Firebase Realtime Database: live/{systemId}/edge
  Stream<EdgeLiveStatus> watchEdgeStatus(String systemId) {
    if (systemId.isEmpty) {
      return Stream.value(const EdgeLiveStatus());
    }

    final ref = _database.ref('live/$systemId/edge');

    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        return EdgeLiveStatus.fromMap(value);
      }
      return const EdgeLiveStatus();
    });
  }

  /// Stream single camera status: live/{systemId}/cameras/{cameraId}
  Stream<Map<String, dynamic>> watchCameraStatus({
    required String systemId,
    required String cameraId,
  }) {
    if (systemId.isEmpty || cameraId.isEmpty) {
      return Stream.value({});
    }

    final ref = _database.ref('live/$systemId/cameras/$cameraId');

    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return {};
    });
  }
}
