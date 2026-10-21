import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pi_connection_profile.dart';
import '../models/system_record.dart';

/// Quản lý danh mục các hệ thống kết nối và kho token phân vùng theo Firebase UID.
/// Hỗ trợ bộ nhớ cục bộ (SharedPreferences & SecureStorage) kết hợp đồng bộ Cloud Firestore.
class SystemRegistryRepository {
  SystemRegistryRepository({
    SharedPreferences? prefs,
    FlutterSecureStorage? secureStorage,
    FirebaseFirestore? firestore,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _firestore = firestore;

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _effectiveFirestore {
    if (_firestore != null) return _firestore;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  bool get isCloudSyncSupported => _effectiveFirestore != null;

  static const String _prefMetadataPrefix = 'ignivo_systems_metadata_v1_';
  static const String _prefActiveSystemPrefix = 'ignivo_active_system_';
  static const String _secureTokenPrefix = 'ignivo_token_';

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Lấy danh sách hệ thống đã lưu theo Firebase UID
  Future<List<SystemRecord>> getSystems(String uid) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('$_prefMetadataPrefix$uid');
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(SystemRecord.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error reading systems metadata for UID $uid: $e');
      return [];
    }
  }

  /// Lưu hoặc cập nhật một hệ thống vào danh mục của UID
  Future<void> saveSystem(
    String uid,
    SystemRecord system, {
    String? token,
  }) async {
    final prefs = await _getPrefs();
    final currentSystems = await getSystems(uid);

    final updated = List<SystemRecord>.from(currentSystems);
    final index = updated.indexWhere((s) => s.systemId == system.systemId);

    if (index >= 0) {
      updated[index] = system;
    } else {
      updated.add(system);
    }

    // Ghi nguyên tử metadata
    final raw = jsonEncode(updated.map((s) => s.toJson()).toList());
    await prefs.setString('$_prefMetadataPrefix$uid', raw);

    // Lưu token vào secure storage nếu có
    if (token != null && token.isNotEmpty) {
      await setSystemToken(uid, system.systemId, token);
    }

    // Nếu chưa có active system, đặt hệ thống này làm active
    final activeId = await getActiveSystemId(uid);
    if (activeId == null || activeId.isEmpty) {
      await setActiveSystemId(uid, system.systemId);
    }

    // Tự động sao lưu lên Cloud Firestore để đồng bộ giữa Web và Mobile
    final firestore = _effectiveFirestore;
    if (firestore != null && uid.isNotEmpty) {
      try {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('registered_systems')
            .doc(system.systemId)
            .set(system.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Warning: Cloud backup failed for system ${system.systemId}: $e');
      }
    }
  }

  /// Gỡ hệ thống khỏi danh mục của UID
  Future<void> removeSystem(String uid, String systemId) async {
    final prefs = await _getPrefs();
    final currentSystems = await getSystems(uid);

    final updated = currentSystems.where((s) => s.systemId != systemId).toList();
    final raw = jsonEncode(updated.map((s) => s.toJson()).toList());
    await prefs.setString('$_prefMetadataPrefix$uid', raw);

    // Xóa token trong secure storage
    await setSystemToken(uid, systemId, null);

    // Xóa trên Cloud Firestore
    final firestore = _effectiveFirestore;
    if (firestore != null && uid.isNotEmpty) {
      try {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('registered_systems')
            .doc(systemId)
            .delete();
      } catch (e) {
        debugPrint('Warning: Cloud delete failed for system $systemId: $e');
      }
    }

    // Nếu hệ thống bị gỡ đang là active system, chuyển active sang hệ thống còn lại đầu tiên
    final activeId = await getActiveSystemId(uid);
    if (activeId == systemId) {
      if (updated.isNotEmpty) {
        await setActiveSystemId(uid, updated.first.systemId);
      } else {
        await prefs.remove('$_prefActiveSystemPrefix$uid');
      }
    }
  }

  /// Đồng bộ danh sách hệ thống từ Cloud Firestore về thiết bị (Web / Mobile)
  Future<List<SystemRecord>> syncFromCloud(String uid) async {
    final firestore = _effectiveFirestore;
    if (firestore == null || uid.isEmpty) {
      return getSystems(uid);
    }

    try {
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('registered_systems')
          .get();

      final localSystems = await getSystems(uid);

      if (snapshot.docs.isEmpty) {
        // Nếu trên Cloud chưa có nhưng cục bộ đã có, tự động đẩy dữ liệu cục bộ lên Cloud
        for (final sys in localSystems) {
          await firestore
              .collection('users')
              .doc(uid)
              .collection('registered_systems')
              .doc(sys.systemId)
              .set(sys.toJson(), SetOptions(merge: true));
        }
        return localSystems;
      }

      final cloudSystems = snapshot.docs.map((doc) {
        final data = doc.data();
        return SystemRecord.fromJson(data);
      }).toList();

      // Hợp nhất (Merge): Ưu tiên Cloud cho cùng systemId, giữ lại hệ thống cục bộ nếu có
      final mergedMap = <String, SystemRecord>{};
      for (final s in localSystems) {
        mergedMap[s.systemId] = s;
      }
      for (final s in cloudSystems) {
        mergedMap[s.systemId] = s;
      }

      final mergedList = mergedMap.values.toList();

      // Cập nhật SharedPreferences cục bộ
      final prefs = await _getPrefs();
      final raw = jsonEncode(mergedList.map((s) => s.toJson()).toList());
      await prefs.setString('$_prefMetadataPrefix$uid', raw);

      // Cập nhật active system nếu cần
      final activeId = await getActiveSystemId(uid);
      if ((activeId == null || !mergedMap.containsKey(activeId)) && mergedList.isNotEmpty) {
        await setActiveSystemId(uid, mergedList.first.systemId);
      }

      return mergedList;
    } catch (e) {
      debugPrint('Error syncing systems from cloud for UID $uid: $e');
      return getSystems(uid);
    }
  }

  /// Lắng nghe các thay đổi hệ thống thời gian thực từ Cloud Firestore
  Stream<List<SystemRecord>> watchCloudSystems(String uid) {
    final firestore = _effectiveFirestore;
    if (firestore == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return firestore
        .collection('users')
        .doc(uid)
        .collection('registered_systems')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SystemRecord.fromJson(doc.data()))
          .toList();
    });
  }

  /// Lấy systemId đang được chọn hoạt động của UID
  Future<String?> getActiveSystemId(String uid) async {
    final prefs = await _getPrefs();
    return prefs.getString('$_prefActiveSystemPrefix$uid');
  }

  /// Đặt systemId hoạt động của UID
  Future<void> setActiveSystemId(String uid, String systemId) async {
    final prefs = await _getPrefs();
    await prefs.setString('$_prefActiveSystemPrefix$uid', systemId);
  }

  /// Lấy token phiên của một hệ thống từ secure storage
  Future<String?> getSystemToken(String uid, String systemId) async {
    try {
      return await _secureStorage.read(
        key: '$_secureTokenPrefix${uid}_$systemId',
      );
    } catch (e) {
      debugPrint('Error reading secure token for system $systemId: $e');
      return null;
    }
  }

  /// Lưu hoặc xóa token phiên của một hệ thống trong secure storage
  Future<void> setSystemToken(
    String uid,
    String systemId,
    String? token,
  ) async {
    try {
      final key = '$_secureTokenPrefix${uid}_$systemId';
      if (token == null || token.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: token);
      }
    } catch (e) {
      debugPrint('Error writing secure token for system $systemId: $e');
    }
  }

  /// Kiểm tra xem có cấu hình cũ (legacy PiConnectionProfile) hay không
  Future<bool> hasLegacyProfile() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(PiConnectionProfile.prefProfileKey);
    return raw != null && raw.isNotEmpty;
  }

  /// Di chuyển cấu hình legacy sang SystemRecord của tài khoản UID
  Future<SystemRecord?> migrateLegacyProfile(String uid) async {
    final prefs = await _getPrefs();
    final legacyProfile = await PiConnectionProfile.load(prefs);

    if (!legacyProfile.isConfigured || legacyProfile.guardUrl.isEmpty) {
      return null;
    }

    // Kiểm tra xem đã tồn tại hệ thống này trong danh mục chưa
    final existing = await getSystems(uid);
    final alreadyExists = existing.any(
      (s) =>
          s.guardUrl == legacyProfile.guardUrl ||
          (legacyProfile.deviceId != null &&
              s.deviceId == legacyProfile.deviceId),
    );

    if (alreadyExists) {
      return existing.firstWhere(
        (s) =>
            s.guardUrl == legacyProfile.guardUrl ||
            (legacyProfile.deviceId != null &&
                s.deviceId == legacyProfile.deviceId),
      );
    }

    final newRecord = SystemRecord.fromPiConnectionProfile(legacyProfile);

    // Di chuyển token cũ nếu có
    final legacyToken = prefs.getString('ignivo_saved_auth_token');
    await saveSystem(uid, newRecord, token: legacyToken);

    return newRecord;
  }
}
