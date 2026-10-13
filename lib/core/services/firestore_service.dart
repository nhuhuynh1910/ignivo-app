import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ============================================================
  // ROOT COLLECTIONS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _systems =>
      _firestore.collection('systems');

  // ============================================================
  // USER PROFILE
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String uid) {
    return _users.doc(uid).get();
  }

  Future<void> createPasswordUserProfile({
    required User user,
    required String name,
    required String phone,
  }) async {
    await _users.doc(user.uid).set({
      'uid': user.uid,
      'name': name.trim(),
      'phone': phone.trim(),
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'authProvider': 'password',
      'profileComplete': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureGoogleUserDocument(User user) async {
    final ref = _users.doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;

    await ref.set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'phone': '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'authProvider': 'google',
      'profileComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeUserProfile({
    required User user,
    required String name,
    required String phone,
  }) async {
    final isGoogle = user.providerData.any(
          (provider) => provider.providerId == 'google.com',
    );

    await _users.doc(user.uid).set(
      {
        'uid': user.uid,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'authProvider': isGoogle ? 'google' : 'password',
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // IGNIVO EDGE BOX SYSTEMS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserSystems(String ownerId) {
    return _systems.where('ownerId', isEqualTo: ownerId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSystem(String systemId) {
    return _systems.doc(systemId).snapshots();
  }

  Future<void> updateSystem({
    required String systemId,
    required Map<String, dynamic> data,
  }) {
    return _systems.doc(systemId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSystem(String systemId) {
    return _systems.doc(systemId).delete();
  }

  // ============================================================
  // IP CAMERAS (systems/{systemId}/cameras)
  // Read-only on mobile. Managed automatically by Edge Box / RPi5.
  // ============================================================

  CollectionReference<Map<String, dynamic>> cameras(String systemId) {
    return _systems.doc(systemId).collection('cameras');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCameras(String systemId) {
    return cameras(systemId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCamera({
    required String systemId,
    required String cameraId,
  }) {
    return cameras(systemId).doc(cameraId).get();
  }

  // Alias for compatibility
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUnits(String systemId) =>
      watchCameras(systemId);

  // ============================================================
  // EVENTS (systems/{systemId}/events)
  // ============================================================

  CollectionReference<Map<String, dynamic>> events(String systemId) {
    return _systems.doc(systemId).collection('events');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEvents(String systemId) {
    return events(systemId).orderBy('createdAt', descending: true).snapshots();
  }

  // ============================================================
  // ALERTS (systems/{systemId}/alerts)
  // ============================================================

  CollectionReference<Map<String, dynamic>> alerts(String systemId) {
    return _systems.doc(systemId).collection('alerts');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAlerts(String systemId) {
    return alerts(systemId).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> acknowledgeAlert({
    required String systemId,
    required String alertId,
  }) {
    return alerts(systemId).doc(alertId).update({
      'acknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAlert(String systemId, String alertId) {
    return alerts(systemId).doc(alertId).delete();
  }
}
