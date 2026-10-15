import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'fireguard_api_service.dart';

class FireeyeException implements Exception {
  const FireeyeException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// One Pi, one revocable session shared by both services. Credentials stay in memory.
class FireeyeApiService {
  FireeyeApiService({http.Client? client, FireguardApiService? fireguard})
    : _client = client ?? http.Client(),
      fireguard = fireguard ?? FireguardApiService.instance {
    this.fireguard.beforeRequest = ensureSession;
    this.fireguard.renewSession = refreshSession;
  }
  static final instance = FireeyeApiService();
  final http.Client _client;
  final FireguardApiService fireguard;
  String _baseUrl = '', _guardOrigin = '';
  String? _refreshToken;
  DateTime? _expires;
  int? _credentialRevision;
  Future<void>? _initializing;
  Future<bool>? _refreshing;
  Map<String, dynamic>? _user;
  String get baseUrl => _baseUrl;
  String? get authToken =>
      _guardOrigin == fireguard.baseUrl ? fireguard.authToken : null;
  bool get authenticated => authToken != null && _user != null;
  bool get canConfigure => ['OWNER', 'ADMIN'].contains(currentUser?['role']);
  Map<String, dynamic>? get currentUser => authenticated ? _user : null;

  static String inferBaseUrl(String guardUrl) => Uri.parse(
    FireguardApiService.normalizeBaseUrl(guardUrl),
  ).replace(port: 8000).toString();
  Future<void> init() => _initializing ??= _load();
  Future<void> _load() async {
    await fireguard.init();
    _guardOrigin = fireguard.baseUrl;
    _baseUrl = inferBaseUrl(_guardOrigin);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('fireeye_guard_origin') == _guardOrigin) {
      final saved = prefs.getString('fireeye_base_url');
      if (saved != null) {
        try {
          _baseUrl = FireguardApiService.normalizeBaseUrl(saved);
        } on FormatException {
          /* Ignore invalid legacy URLs. */
        }
      }
    }
  }

  void _forgetRefresh() {
    _refreshToken = null;
    _expires = null;
    _credentialRevision = null;
  }

  Future<void> configure(String url) async {
    await init();
    final normalized = FireguardApiService.normalizeBaseUrl(url);
    if (_baseUrl != normalized || _guardOrigin != fireguard.baseUrl) {
      _forgetRefresh();
      await fireguard.setAuthToken(null);
      _user = null;
    }
    _baseUrl = normalized;
    _guardOrigin = fireguard.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fireeye_base_url', _baseUrl);
    await prefs.setString('fireeye_guard_origin', _guardOrigin);
  }

  Future<void> ensureSession() async {
    await init();
    if (_credentialRevision != fireguard.sessionRevision ||
        _guardOrigin != fireguard.baseUrl) {
      _forgetRefresh();
      return;
    }
    if (_expires != null &&
        DateTime.now().isAfter(
          _expires!.subtract(const Duration(seconds: 60)),
        )) {
      await refreshSession();
    }
  }

  Future<bool> refreshSession() async {
    if (_refreshing != null) return _refreshing!;
    final pending = _refresh();
    _refreshing = pending;
    try {
      return await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  Future<bool> _refresh() async {
    if (_refreshToken == null ||
        _credentialRevision != fireguard.sessionRevision ||
        _guardOrigin != fireguard.baseUrl) {
      return false;
    }
    final revision = fireguard.sessionRevision;
    final data = await _request(
      '/api/auth/refresh',
      method: 'POST',
      authorize: false,
      body: {'refresh_token': _refreshToken},
    );
    if (revision != fireguard.sessionRevision) {
      throw const FireeyeException(
        'Phiên đã thay đổi. Vui lòng đăng nhập lại.',
      );
    }
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const FireeyeException('FireEye chưa hỗ trợ gia hạn phiên mobile.');
    }
    await fireguard.setAuthToken(token, preserveUser: true);
    _expires = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 1800),
    );
    return true;
  }

  Future<http.Response> _exchange(
    http.BaseRequest Function() create, {
    bool authorize = true,
    bool retried = false,
  }) async {
    await init();
    if (authorize) await ensureSession();
    final origin = _baseUrl, guardOrigin = _guardOrigin;
    final revision = fireguard.sessionRevision, token = authToken;
    try {
      final request = create()..followRedirects = false;
      request.headers['Accept'] = 'application/json';
      if (authorize && token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 20));
      if (_baseUrl != origin ||
          fireguard.baseUrl != guardOrigin ||
          fireguard.sessionRevision != revision) {
        throw const FireeyeException('Kết nối đã thay đổi. Vui lòng tải lại.');
      }
      if (response.statusCode == 401) {
        if (authorize &&
            !retried &&
            (token != authToken || await refreshSession())) {
          return _exchange(create, authorize: authorize, retried: true);
        }
        if (authorize || request.url.path.endsWith('/refresh')) {
          _forgetRefresh();
          _user = null;
          await fireguard.setAuthToken(null);
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        dynamic detail;
        try {
          detail = jsonDecode(utf8.decode(response.bodyBytes))['detail'];
        } catch (_) {}
        if (request.url.path.endsWith('/login') && response.statusCode == 401) {
          throw FireeyeException(
            'Đăng nhập FireEye thất bại. ${detail is String ? detail : 'Kiểm tra số điện thoại và mật khẩu.'}',
            401,
          );
        }
        throw FireeyeException(
          detail is String
              ? detail
              : response.statusCode == 401
              ? 'Phiên đã hết hạn. Vui lòng đăng nhập lại.'
              : response.statusCode == 403
              ? 'Bạn không có quyền thực hiện thao tác này.'
              : 'FireEye trả về lỗi ${response.statusCode}. Kiểm tra dữ liệu và thử lại.',
          response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const FireeyeException(
        'FireEye phản hồi quá chậm. Kiểm tra mạng/Tailscale.',
      );
    } on http.ClientException {
      throw const FireeyeException(
        'Không kết nối được FireEye. Kiểm tra mạng và cổng 8000.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const FireeyeException('FireEye trả về dữ liệu không hợp lệ.');
    }
    if (data is Map &&
        (data['success'] == false || data['status'] == 'error')) {
      throw FireeyeException(
        '${data['message'] ?? 'FireEye không thực hiện được thao tác.'}',
      );
    }
    return data;
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Object? body,
    bool authorize = true,
  }) async {
    await init();
    return _decode(
      await _exchange(() {
        final r = http.Request(method, Uri.parse('$_baseUrl$path'));
        r.headers['Content-Type'] = 'application/json';
        if (body != null) r.body = jsonEncode(body);
        return r;
      }, authorize: authorize),
    );
  }

  Future<void> login({
    required String phoneNumber,
    required String secretKey,
    required String systemSecretKey,
  }) async {
    await init();
    _forgetRefresh();
    _user = null;
    await fireguard.setAuthToken(null);
    final data = await _request(
      '/api/auth/login',
      method: 'POST',
      authorize: false,
      body: {
        'phone_number': phoneNumber.trim(),
        'secret_key': secretKey,
        'system_secret_key': systemSecretKey,
        'device_name': 'IGNIVO Mobile App',
      },
    );
    final token = data is Map ? data['token'] : null;
    if (token is! String || token.isEmpty) {
      throw const FireeyeException('FireEye không trả về access token.');
    }
    await fireguard.setAuthToken(token);
    _refreshToken = data['refresh_token'] as String?;
    _credentialRevision = fireguard.sessionRevision;
    _expires = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 1800),
    );
    final revision = fireguard.sessionRevision;
    try {
      await getCurrentUser();
    } catch (_) {
      if (revision == fireguard.sessionRevision) {
        _forgetRefresh();
        await fireguard.setAuthToken(null);
      }
      rethrow;
    }
  }

  Future<void> useToken(String token) async {
    await init();
    _forgetRefresh();
    _user = null;
    await fireguard.setAuthToken(token);
    final revision = fireguard.sessionRevision;
    try {
      await getCurrentUser();
    } catch (_) {
      if (revision == fireguard.sessionRevision) {
        await fireguard.setAuthToken(null);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async =>
      _user = Map<String, dynamic>.from(await _request('/api/auth/me'));
  Future<void> logout() async {
    final revision = fireguard.sessionRevision;
    try {
      if (authToken != null) await _request('/api/auth/logout', method: 'POST');
    } finally {
      if (revision == fireguard.sessionRevision) {
        _forgetRefresh();
        _user = null;
        await fireguard.setAuthToken(null);
      }
    }
  }

  Future<Map<String, dynamic>> getCameraCapabilities({
    String? sourceRevision,
  }) async {
    final query = sourceRevision != null && sourceRevision.isNotEmpty
        ? '?source_revision=${Uri.encodeComponent(sourceRevision)}'
        : '';
    return Map<String, dynamic>.from(
      await _request('/api/integration/camera$query'),
    );
  }

  Future<void> bindCamera(
    String device,
    int camera, {
    String? sourceRevision,
  }) async => _request(
    '/api/integration/camera',
    method: 'PUT',
    body: {
      'guard_device_id': device,
      'guard_camera_id': camera,
      'source_revision': ?sourceRevision,
    },
  );

  Future<void> unbindCamera() async =>
      _request('/api/integration/camera', method: 'DELETE');

  Future<void> ptz(
    String device,
    int camera,
    String action, {
    String stopCode = 'left',
    String? sourceRevision,
  }) async => _request(
    '/api/integration/ptz',
    method: 'POST',
    body: {
      'guard_device_id': device,
      'guard_camera_id': camera,
      'action': action,
      'stop_code': stopCode,
      'source_revision': ?sourceRevision,
    },
  );
  Future<Map<String, dynamic>> getFaceStatus() async =>
      Map<String, dynamic>.from(await _request('/api/faces/watch/status'));
  Future<void> setFaceWatch(bool enabled) async => _request(
    '/api/faces/watch/${enabled ? 'start' : 'stop'}',
    method: 'POST',
  );
  Future<List<Map<String, dynamic>>> getPeople() async =>
      List<Map<String, dynamic>>.from(
        (await _request('/api/faces/people'))['data'],
      );
  Future<void> deletePerson(int id) async =>
      _request('/api/faces/people/$id', method: 'DELETE');
  Future<void> registerFace(
    String name, {
    required bool consent,
    Uint8List? image,
  }) async {
    if (!consent) {
      throw const FireeyeException(
        'Cần xác nhận sự đồng ý của người tham gia.',
      );
    }
    _decode(
      await _exchange(() {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(
            '$_baseUrl/api/faces/${image == null ? 'register-camera' : 'register'}',
          ),
        );
        request.fields.addAll({'name': name.trim(), 'consent': '$consent'});
        if (image != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              image,
              filename: 'portrait.jpg',
            ),
          );
        }
        return request;
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getEvents({
    int? beforeId,
    String? type,
  }) async {
    final query = Uri(
      queryParameters: {
        'limit': '50',
        if (beforeId != null) 'before_id': '$beforeId',
        'event_type': ?type,
      },
    ).query;
    return List<Map<String, dynamic>>.from(
      (await _request('/api/events?$query'))['data'],
    );
  }

  Future<void> markEventRead(int id) async =>
      _request('/api/notifications/$id/read', method: 'POST');
  Future<Uint8List> getImage(String path) async {
    if (!RegExp(
          r'^/static/(faces|snapshots)/[a-zA-Z0-9_.-]+\.(jpg|jpeg|png)$',
        ).hasMatch(path) &&
        path != '/api/camera/raw-frame') {
      throw const FireeyeException('Đường dẫn ảnh không hợp lệ.');
    }
    return (await _exchange(
      () => http.Request('GET', Uri.parse('$_baseUrl$path')),
    )).bodyBytes;
  }
}
