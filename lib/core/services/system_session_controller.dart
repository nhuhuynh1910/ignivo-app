import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pi_connection_profile.dart';
import 'fireguard_api_service.dart';

enum SessionStatus {
  unconfigured,
  unauthenticated,
  authenticating,
  authenticated,
  sessionExpired,
}

class SystemSessionController extends ChangeNotifier {
  SystemSessionController({
    FireguardApiService? api,
    PiConnectionProfile? initialProfile,
  })  : api = api ?? FireguardApiService(),
        _profile = initialProfile ?? PiConnectionProfile.createUnconfigured() {
    _status = _profile.isConfigured
        ? SessionStatus.unauthenticated
        : SessionStatus.unconfigured;
    if (_profile.guardUrl.isNotEmpty) {
      this.api.setBaseUrl(_profile.guardUrl);
    }
  }

  final FireguardApiService api;
  PiConnectionProfile _profile;
  SessionStatus _status = SessionStatus.unconfigured;
  Map<String, dynamic>? _currentUser;
  String? _lastError;
  int _sessionRevision = 0;

  PiConnectionProfile get profile => _profile;
  SessionStatus get status => _status;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get lastError => _lastError;
  int get sessionRevision => _sessionRevision;

  String get systemName => _profile.systemName;
  String get guardUrl => _profile.guardUrl;
  String? get deviceId => _profile.deviceId;
  bool get isConfigured => _profile.isConfigured && _profile.guardUrl.isNotEmpty;

  /// Returns true ONLY after `/auth/me` has verified the session and token is present.
  bool get isAuthenticated =>
      _status == SessionStatus.authenticated &&
      _currentUser != null &&
      api.authToken != null &&
      api.authToken!.isNotEmpty;

  String? get role => _currentUser?['role']?.toString();
  String? get username => _currentUser?['username']?.toString();
  String? get fullName => _currentUser?['full_name']?.toString() ?? username;
  String? get phoneNumber => _currentUser?['phone_number']?.toString();

  bool get isOwnerOrAdmin =>
      isAuthenticated && (role == 'OWNER' || role == 'ADMIN');

  /// Any authenticated role is allowed to handle emergency incidents (ACK, Resolve, False Alarm).
  bool get canHandleIncidents => isAuthenticated;

  Future<void> initialize(SharedPreferences prefs) async {
    _profile = await PiConnectionProfile.load(prefs);
    if (!_profile.isConfigured || _profile.guardUrl.isEmpty) {
      _status = SessionStatus.unconfigured;
    } else {
      await api.setBaseUrl(_profile.guardUrl);
      _status = SessionStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({
    required String phoneNumber,
    required String secretKey,
    required String systemSecretKey,
    String deviceName = 'IGNIVO Mobile App',
    SharedPreferences? prefs,
  }) async {
    _lastError = null;
    _status = SessionStatus.authenticating;
    notifyListeners();

    try {
      final ok = await api.login(
        phoneNumber: phoneNumber,
        secretKey: secretKey,
        systemSecretKey: systemSecretKey,
        deviceName: deviceName,
      );

      if (!ok) {
        _status = SessionStatus.unauthenticated;
        _lastError = api.lastError ?? 'Đăng nhập thất bại. Vui lòng thử lại.';
        notifyListeners();
        return false;
      }

      // Mandatory token confirmation via /auth/me
      Map<String, dynamic> user;
      try {
        user = await api.getCurrentUser();
      } catch (e) {
        await api.setAuthToken(null);
        _currentUser = null;
        _status = SessionStatus.unauthenticated;
        _lastError = 'Không thể xác thực thông tin tài khoản từ FireGuard.';
        notifyListeners();
        return false;
      }

      if (user.isEmpty) {
        await api.setAuthToken(null);
        _currentUser = null;
        _status = SessionStatus.unauthenticated;
        _lastError = 'Thông tin người dùng rỗng. Vui lòng đăng nhập lại.';
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _sessionRevision++;
      _status = SessionStatus.authenticated;

      // Read device_id from /system/info if not already cached in profile
      if (_profile.deviceId == null) {
        try {
          final info = await api.getSystemInfo();
          final devId = info?['device_id']?.toString();
          if (devId != null && devId.isNotEmpty) {
            _profile = _profile.copyWith(deviceId: devId);
            final sp = prefs ?? await SharedPreferences.getInstance();
            await _profile.save(sp);
          }
        } catch (_) {}
      }

      notifyListeners();
      return true;
    } catch (e) {
      _status = SessionStatus.unauthenticated;
      _lastError = e is FireguardException ? e.message : '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _sessionRevision++;
    try {
      await api.logout();
    } catch (_) {}
    await api.setAuthToken(null);
    _currentUser = null;
    _status = SessionStatus.unauthenticated;
    _lastError = null;
    notifyListeners();
  }

  Future<void> updateProfile(
    PiConnectionProfile newProfile,
    SharedPreferences prefs,
  ) async {
    final hostChanged = newProfile.guardUrl != _profile.guardUrl;
    if (hostChanged) {
      _sessionRevision++;
      await api.setAuthToken(null);
      _currentUser = null;
    }

    _profile = newProfile;
    await _profile.save(prefs);

    if (_profile.isConfigured && _profile.guardUrl.isNotEmpty) {
      await api.setBaseUrl(_profile.guardUrl);
      _status = SessionStatus.unauthenticated;
    } else {
      _status = SessionStatus.unconfigured;
    }
    _lastError = null;
    notifyListeners();
  }

  void handleSessionExpired([String? reason]) {
    if (_status == SessionStatus.sessionExpired) return;
    _sessionRevision++;
    api.setAuthToken(null);
    _currentUser = null;
    _status = SessionStatus.sessionExpired;
    _lastError = reason ??
        'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại để tiếp tục giám sát.';
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
