import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FireguardException implements Exception {
  const FireguardException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Adapter for the existing FireGuard API. Firebase IDs/tokens are not used.
class FireguardApiService {
  FireguardApiService({http.Client? client})
    : _client = client ?? http.Client();
  static final instance = FireguardApiService();
  final http.Client _client;
  static const defaultBaseUrl = 'http://100.95.189.60:8080';
  static const _prefBaseUrlKey = 'fireguard_edge_base_url';
  static const _prefAuthTokenKey = 'fireguard_edge_auth_token';
  String _baseUrl = defaultBaseUrl;
  String? _authToken;
  final _sessionChanges = StreamController<void>.broadcast(sync: true);
  Stream<void> get sessionChanges => _sessionChanges.stream;
  Future<void>? _initializing;
  Map<String, dynamic>? currentUser;
  String? lastError;
  String? lastCallProvider;
  Future<void> Function()? beforeRequest;
  Future<bool> Function()? renewSession;
  int _sessionRevision = 0;
  int get sessionRevision => _sessionRevision;

  String get baseUrl => _baseUrl;
  String? get authToken => _authToken;
  String get apiPrefix => '$_baseUrl/api/v1/emergency';
  bool get canConfigure => ['OWNER', 'ADMIN'].contains(currentUser?['role']);
  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<void> init() => _initializing ??= _load();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefBaseUrlKey);
    if (saved != null) {
      try {
        _baseUrl = normalizeBaseUrl(saved);
      } on FormatException {
        /* Old invalid setting. */
      }
    }
    // Tokens are session-only; remove credentials persisted by older versions.
    await prefs.remove(_prefAuthTokenKey);
  }

  static String normalizeBaseUrl(String value) {
    var input = value.trim();
    if (!input.contains('://')) input = 'http://$input';
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.host.contains(RegExp(r'\s')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Nhập địa chỉ gốc, ví dụ http://192.168.1.50:8080 (không kèm /api).',
      );
    }
    return uri.replace(path: '').toString();
  }

  Future<void> setBaseUrl(String value) async {
    await init();
    final url = normalizeBaseUrl(value);
    if (_baseUrl != url) {
      _sessionRevision++;
      _authToken = null;
      currentUser = null;
    }
    _baseUrl = url;
    _sessionChanges.add(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrlKey, url);
  }

  Future<void> setAuthToken(String? token, {bool preserveUser = false}) async {
    await init();
    final cleaned = token?.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    _authToken = cleaned == null || cleaned.isEmpty ? null : cleaned;
    if (!preserveUser) {
      _sessionRevision++;
      currentUser = null;
    }
    _sessionChanges.add(null);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool retried = false,
  }) async {
    await init();
    try {
      await beforeRequest?.call();
    } catch (e) {
      lastError = '$e';
      throw FireguardException(lastError!);
    }
    lastError = null;
    final token = _authToken;
    final origin = _baseUrl;
    final revision = _sessionRevision;
    try {
      final request = http.Request(
        method,
        Uri.parse('$apiPrefix$path').replace(queryParameters: query),
      );
      request.followRedirects = false;
      request.headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 12));
      if (_baseUrl != origin || _sessionRevision != revision) {
        throw const FireguardException(
          'Kết nối đã thay đổi. Vui lòng tải lại.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'FireGuard trả về HTTP ${response.statusCode}';
        try {
          final detail = jsonDecode(utf8.decode(response.bodyBytes))['detail'];
          if (detail is String) message = detail;
          if (detail is List) message = detail.map((e) => e['msg']).join('; ');
        } catch (_) {
          /* Preserve the HTTP status for non-JSON responses. */
        }
        if (response.statusCode == 401) {
          if (path != '/auth/login') {
            if (!retried &&
                (_authToken != token ||
                    await (renewSession?.call() ?? Future.value(false)))) {
              return _request(
                method,
                path,
                body: body,
                query: query,
                retried: true,
              );
            }
            if (_authToken == token) {
              _authToken = null;
              currentUser = null;
              _sessionChanges.add(null);
            }
            message =
                'Phiên FireGuard hết hạn hoặc chưa đăng nhập. Vui lòng đăng nhập lại bằng tài khoản FireEye.';
          }
        }
        throw FireguardException(message, response.statusCode);
      }
      return response;
    } on FireguardException catch (e) {
      lastError = e.message;
      rethrow;
    } catch (_) {
      lastError =
          'Không thể kết nối FireGuard. Kiểm tra địa chỉ, mạng và cổng 8080.';
      throw FireguardException(lastError!);
    }
  }

  dynamic _decode(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));
  Future<Map<String, dynamic>> _map(String path) async =>
      Map<String, dynamic>.from(_decode(await _request('GET', path)) as Map);
  Future<List<Map<String, dynamic>>> _list(
    String path, {
    Map<String, String>? query,
  }) async => (_decode(await _request('GET', path, query: query)) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<bool> _write(String method, String path, {Object? body}) async {
    try {
      await _request(method, path, body: body);
      return true;
    } on FireguardException {
      return false;
    }
  }

  Future<bool> login({
    required String phoneNumber,
    required String secretKey,
    required String systemSecretKey,
    String deviceName = 'IGNIVO Mobile App',
  }) async {
    try {
      final data = _decode(
        await _request(
          'POST',
          '/auth/login',
          body: {
            'phone_number': phoneNumber.trim(),
            'secret_key': secretKey,
            'system_secret_key': systemSecretKey,
            'device_name': deviceName,
          },
        ),
      );
      final token = data['token'];
      if (token is! String || token.isEmpty) {
        lastError = 'FireGuard không trả về token đăng nhập.';
        return false;
      }
      await setAuthToken(token);
      await getCurrentUser();
      return true;
    } on FireguardException {
      return false;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async =>
      currentUser = await _map('/auth/me');
  Future<void> logout() async {
    try {
      if (_authToken != null) await _request('POST', '/auth/logout');
    } finally {
      await setAuthToken(null);
    }
  }

  Future<bool> checkConnection() async {
    try {
      final health = await _map('/health');
      return health['status'] == 'ok' && health['service'] == 'fireguard';
    } on FireguardException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSystemInfo() async {
    try {
      return await _map('/system/info');
    } on FireguardException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final info = await _map('/system/info');
      final status = await _map('/status');
      final vision = status['vision'] as Map? ?? {};
      return {
        ...info,
        ...status,
        'hailo_ready': vision['ready'],
        'hailo_error': vision['error'],
        'total_ai_fps': vision['total_ai_fps'],
      };
    } on FireguardException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCameras() => _list('/cameras');
  Future<bool> saveCamera(Map<String, dynamic> data, {int? id}) => _write(
    id == null ? 'POST' : 'PUT',
    id == null ? '/cameras' : '/cameras/$id',
    body: data,
  );
  Future<Map<String, dynamic>> getEscalationSettings() =>
      _map('/settings/escalation');
  Future<bool> updateEscalationSettings(Map<String, dynamic> data) =>
      _write('PUT', '/settings/escalation', body: data);
  String getMjpegStreamUrl(dynamic id) => '$apiPrefix/cameras/$id/stream';
  String getSnapshotUrl(dynamic id) => '$apiPrefix/cameras/$id/snapshot';
  bool ownsUrl(String value) {
    final url = Uri.tryParse(value);
    final base = Uri.parse(_baseUrl);
    return url != null &&
        ['http', 'https'].contains(url.scheme) &&
        url.hasAuthority &&
        url.origin == base.origin &&
        url.path.startsWith('/api/v1/emergency/');
  }

  Map<String, String> headersForUrl(String value) =>
      ownsUrl(value) ? _headers : {};

  Future<List<Map<String, dynamic>>> getIncidents({
    String? status,
    int limit = 50,
  }) => _list(
    '/incidents',
    query: {'limit': '${limit.clamp(1, 200)}', 'status': ?status},
  );
  Future<Map<String, dynamic>?> getIncidentDetail(int id) =>
      _map('/incidents/$id');
  Future<Map<String, dynamic>?> getActiveIncident() async {
    final data = _decode(await _request('GET', '/incidents/active'));
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Uri get websocketUri => Uri.parse('$apiPrefix/ws').replace(
    scheme: Uri.parse(_baseUrl).scheme == 'https' ? 'wss' : 'ws',
    queryParameters: {'token': ?_authToken},
  );
  Future<bool> acknowledgeIncident(
    int id, {
    String note = 'Xác nhận từ IGNIVO',
  }) => _write('POST', '/incidents/$id/ack', body: {'note': note});
  Future<bool> falseAlarmIncident(
    int id, {
    String note = 'Báo nhầm từ IGNIVO',
  }) => _write('POST', '/incidents/$id/false-alarm', body: {'note': note});
  Future<bool> resolveIncident(int id, {String note = 'Đã xử lý từ IGNIVO'}) =>
      _write('POST', '/incidents/$id/resolve', body: {'note': note});
  String getIncidentImageUrl(dynamic id, {dynamic image = '00.jpg'}) {
    var name = image.toString();
    if (RegExp(r'^\d+$').hasMatch(name)) name = '${name.padLeft(2, '0')}.jpg';
    return '$apiPrefix/incidents/$id/images/${Uri.encodeComponent(name)}';
  }

  /// Fetch bytes with Bearer headers: incident images do not accept ?token=.
  Future<Uint8List> getIncidentImage(int id, String name) async {
    if (!RegExp(r'^(\d{2}|analysis_\d+)\.jpg$').hasMatch(name)) {
      throw const FireguardException('Tên ảnh sự cố không hợp lệ.');
    }
    return (await _request('GET', '/incidents/$id/images/$name')).bodyBytes;
  }

  Future<List<Map<String, dynamic>>> getContacts({String? kind}) =>
      _list('/contacts', query: {'kind': ?kind});
  Future<Map<String, dynamic>?> createContact({
    required String name,
    required String phone,
    String relation = '',
    String kind = 'family',
    int priority = 1,
    bool enabled = true,
  }) async {
    try {
      return Map<String, dynamic>.from(
        _decode(
              await _request(
                'POST',
                '/contacts',
                body: {
                  'name': name.trim(),
                  'phone': phone.trim(),
                  'relation': relation.trim(),
                  'kind': kind,
                  'priority': priority,
                  'enabled': enabled,
                },
              ),
            )
            as Map,
      );
    } on FireguardException {
      return null;
    }
  }

  Future<bool> updateContact(int id, Map<String, dynamic> data) =>
      _write('PUT', '/contacts/$id', body: data);
  Future<bool> deleteContact(int id) => _write('DELETE', '/contacts/$id');
  Future<bool> testCall(int id) async {
    lastCallProvider = null;
    try {
      final result = _decode(await _request('POST', '/test/call/$id'));
      lastCallProvider = result['provider']?.toString();
      if (result['ok'] == true) return true;
      lastError =
          result['error']?.toString() ??
          'FireGuard không thực hiện được cuộc gọi.';
      return false;
    } on FireguardException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getLocationSettings() async {
    try {
      return await _map('/settings/location');
    } on FireguardException {
      return null;
    }
  }

  Future<bool> updateLocationSettings({
    required String address,
    String building = '',
    String floor = '',
    String room = '',
    String landmark = '',
    double? latitude,
    double? longitude,
    String notes = '',
  }) => _write(
    'PUT',
    '/settings/location',
    body: {
      'address': address.trim(),
      'building': building.trim(),
      'floor': floor.trim(),
      'room': room.trim(),
      'landmark': landmark.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes.trim(),
    },
  );

  Future<bool> registerNotificationDevice({
    required String installationId,
    required String token,
    String platform = 'android',
    String? deviceName,
  }) => _write(
    'POST',
    '/notification-devices',
    body: {
      'installation_id': installationId,
      'token': token,
      'platform': platform,
      'device_name': ?deviceName,
    },
  );

  Future<bool> unregisterNotificationDevice(String installationId) => _write(
    'DELETE',
    '/notification-devices/${Uri.encodeComponent(installationId)}',
  );
}

