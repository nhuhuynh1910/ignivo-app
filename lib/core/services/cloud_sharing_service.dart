import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;


/// Dịch vụ kết nối tới Ignivo Cloud Serverless Backend cho Registry, Chia sẻ & Phân quyền.
class CloudSharingService {
  CloudSharingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    String? functionsBaseUrl,
  })  : _providedAuth = auth,
        _providedFirestore = firestore,
        _client = httpClient ?? http.Client(),
        _functionsBaseUrl = functionsBaseUrl ??
            'https://us-central1-ignivo-firebase.cloudfunctions.net';

  final FirebaseAuth? _providedAuth;
  final FirebaseFirestore? _providedFirestore;
  final http.Client _client;
  final String _functionsBaseUrl;

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _providedFirestore ?? FirebaseFirestore.instance;


  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Gọi một Firebase Cloud Function (giao thức HTTPS Callable)
  Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final token = await _getIdToken();
    if (token == null) {
      throw StateError('Người dùng chưa đăng nhập tài khoản Cloud.');
    }

    final url = Uri.parse('$_functionsBaseUrl/$functionName');
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': data}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('result')) {
        final result = decoded['result'];
        if (result is Map<String, dynamic>) {
          return result;
        }
        return {'result': result};
      }
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    // Xử lý lỗi trả về từ Callable Function
    try {
      final errorBody = jsonDecode(response.body);
      final message = errorBody?['error']?['message'] ??
          errorBody?['message'] ??
          'Lỗi máy chủ (${response.statusCode})';
      throw Exception(message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Yêu cầu thất bại: HTTP ${response.statusCode}');
    }
  }

  // ============================================================
  // PROVISIONING & CLAIMING
  // ============================================================

  /// Yêu cầu sinh challenge để xác thực quyền sở hữu thiết bị Pi
  Future<Map<String, dynamic>> createClaimChallenge(String deviceId) async {
    return await callFunction('createClaimChallenge', {'deviceId': deviceId});
  }

  /// Gửi chữ ký số Ed25519 của Pi để đăng ký/claim thiết bị
  Future<Map<String, dynamic>> claimDevice({
    required String challengeId,
    required String signature,
    required String systemName,
    String? location,
    String? guardUrl,
    String? fireEyeUrl,
  }) async {
    return await callFunction('claimDevice', {
      'challengeId': challengeId,
      'signature': signature,
      'systemName': systemName,
      'location': location,
      'guardUrl': guardUrl,
      'fireEyeUrl': fireEyeUrl,
    });
  }

  // ============================================================
  // INVITATIONS & SHARING
  // ============================================================

  /// Tạo lời mời người dùng mới tham gia hệ thống
  Future<Map<String, dynamic>> createInvitation({
    required String systemId,
    required String inviteeEmail,
    required String role,
  }) async {
    return await callFunction('createInvitation', {
      'systemId': systemId,
      'inviteeEmail': inviteeEmail.trim().toLowerCase(),
      'role': role,
    });
  }

  /// Chấp nhận lời mời tham gia hệ thống
  Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    return await callFunction('acceptInvitation', {
      'invitationId': invitationId,
    });
  }

  /// Thu hồi quyền thành viên
  Future<Map<String, dynamic>> revokeMembership({
    required String systemId,
    required String targetUid,
  }) async {
    return await callFunction('revokeMembership', {
      'systemId': systemId,
      'targetUid': targetUid,
    });
  }

  /// Yêu cầu cấp PiGrant token để đổi phiên trực tiếp trên Pi
  Future<Map<String, dynamic>> issuePiGrant(String systemId) async {
    return await callFunction('issuePiGrant', {
      'systemId': systemId,
    });
  }

  // ============================================================
  // FIRESTORE STREAMS
  // ============================================================

  /// Theo dõi danh sách thành viên của một hệ thống
  Stream<List<Map<String, dynamic>>> watchMembers(String systemId) {
    return _firestore
        .collection('systems')
        .doc(systemId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Theo dõi các lời mời đang chờ xử lý theo email người dùng
  Stream<List<Map<String, dynamic>>> watchPendingInvitations(String email) {
    if (email.isEmpty) return Stream.value([]);
    return _firestore
        .collection('invitations')
        .where('inviteeEmail', isEqualTo: email.trim().toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['invitationId'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Theo dõi danh sách lời mời đã gửi của một hệ thống
  Stream<List<Map<String, dynamic>>> watchSystemInvitations(String systemId) {
    return _firestore
        .collection('invitations')
        .where('systemId', isEqualTo: systemId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['invitationId'] = doc.id;
        return data;
      }).toList();
    });
  }
}
