import 'package:cloud_firestore/cloud_firestore.dart';

class EdgePairingService {
  EdgePairingService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Claims an IGNIVO Edge Box using its printed Edge Code.
  /// Calls Cloud Function / Backend verification in production.
  Future<String> claimEdgeBox({
    required String ownerId,
    required String edgeCode,
  }) async {
    final cleanCode = edgeCode.trim().toUpperCase();

    // In production, call Firebase Cloud Function:
    // final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('claimEdgeBox');
    // final response = await callable.call({'edgeCode': cleanCode});
    // return response.data['systemId'];

    // Direct Firestore binding (Fallback / Prototype):
    final existing = await _firestore
        .collection('systems')
        .where('ownerId', isEqualTo: ownerId)
        .where('edgeCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final newDoc = await _firestore.collection('systems').add({
      'ownerId': ownerId,
      'name': 'IGNIVO Box $cleanCode',
      'locationName': '',
      'edgeBoxId': cleanCode,
      'edgeCode': cleanCode,
      'cameraCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newDoc.id;
  }
}
