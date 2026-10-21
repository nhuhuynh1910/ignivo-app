import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/system_record.dart';

import 'cloud_sharing_service.dart';
import 'system_registry_repository.dart';

/// Dịch vụ quản lý chu trình PiGrant: cấp từ Cloud và đổi lấy phiên trên Pi.
class PiGrantService {
  PiGrantService({
    CloudSharingService? cloudSharingService,
    SystemRegistryRepository? registry,
    http.Client? httpClient,
  })  : _cloud = cloudSharingService ?? CloudSharingService(),
        _registry = registry ?? SystemRegistryRepository(),
        _client = httpClient ?? http.Client();

  final CloudSharingService _cloud;
  final SystemRegistryRepository _registry;
  final http.Client _client;

  /// Đổi PiGrant lấy phiên đăng nhập cục bộ trên Edge Box (Raspberry Pi)
  Future<Map<String, dynamic>> exchangeGrantOnPi({
    required String guardUrl,
    required String grantToken,
    String? installationId,
    String? deviceName,
  }) async {
    final cleanUrl = guardUrl.endsWith('/')
        ? guardUrl.substring(0, guardUrl.length - 1)
        : guardUrl;
    final url = Uri.parse('$cleanUrl/api/v1/auth/exchange-grant');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_token': grantToken,
        'installation_id': installationId,
        'device_name': deviceName ?? 'Ignivo Mobile App',
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Phản hồi không đúng định dạng JSON từ Pi.');
    }

    try {
      final error = jsonDecode(response.body);
      final msg = error?['detail'] ?? 'Lỗi đổi PiGrant (HTTP ${response.statusCode})';
      throw Exception(msg);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Không thể đổi PiGrant trên Pi: HTTP ${response.statusCode}');
    }
  }

  /// Yêu cầu Pi ký challenge bằng khóa riêng tư phần cứng
  Future<Map<String, dynamic>> signClaimChallengeOnPi({
    required String guardUrl,
    required String challenge,
  }) async {
    final cleanUrl = guardUrl.endsWith('/')
        ? guardUrl.substring(0, guardUrl.length - 1)
        : guardUrl;
    final url = Uri.parse('$cleanUrl/api/v1/auth/sign-claim-challenge');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'challenge': challenge}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Phản hồi ký challenge không đúng định dạng.');
    }

    try {
      final error = jsonDecode(response.body);
      throw Exception(error?['detail'] ?? 'Lỗi ký challenge trên Pi (${response.statusCode})');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Không thể ký challenge trên Pi: HTTP ${response.statusCode}');
    }
  }

  /// Tự động lấy PiGrant từ Cloud và kích hoạt phiên cục bộ cho hệ thống được chia sẻ
  Future<String> obtainAndStorePiSession({
    required String uid,
    required SystemRecord system,
    String? installationId,
  }) async {
    // 1. Yêu cầu Cloud cấp PiGrant
    final grantResult = await _cloud.issuePiGrant(system.systemId);
    final grantToken = grantResult['grantToken']?.toString();
    if (grantToken == null || grantToken.isEmpty) {
      throw StateError('Không nhận được PiGrant token từ Ignivo Cloud.');
    }

    final role = grantResult['role']?.toString() ?? system.role;

    // 2. Gửi PiGrant tới Pi để nhận local session JWT
    final exchangeResult = await exchangeGrantOnPi(
      guardUrl: system.guardUrl,
      grantToken: grantToken,
      installationId: installationId,
    );

    final localToken = exchangeResult['token']?.toString();
    if (localToken == null || localToken.isEmpty) {
      throw StateError('Pi không trả về access token hợp lệ.');
    }

    // 3. Cập nhật role thực tế và lưu token vào Secure Storage
    final updatedSystem = system.copyWith(
      role: role,
      status: 'connected',
      lastConnectedAt: DateTime.now(),
    );
    await _registry.saveSystem(uid, updatedSystem, token: localToken);

    return localToken;
  }
}
