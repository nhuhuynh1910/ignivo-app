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

  static const prefSavedAuthTokenKey = 'ignivo_saved_auth_token';
  static const prefRememberMeKey = 'ignivo_remember_me';

  final FireguardApiService api;
  PiConnectionProfile _profile;
  SessionStatus _status = SessionStatus.unconfigured;
  Map<String, dynamic>? _currentUser;
  String? _lastError;
  int _sessionRevision = 0;
  bool _rememberMe = true;

  PiConnectionProfile get profile => _profile;
  SessionStatus get status => _status;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get lastError => _lastError;
  int get sessionRevision => _sessionRevision;
  bool get rememberMe => _rememberMe;

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
    _rememberMe = prefs.getBool(prefRememberMeKey) ?? true;

    if (!_profile.isConfigured || _profile.guardUrl.isEmpty) {
      _status = SessionStatus.unconfigured;
      notifyListeners();
      return;
    }

    await api.setBaseUrl(_profile.guardUrl);

    // If rememberMe is enabled, check for a persisted session token
    final savedToken = prefs.getString(prefSavedAuthTokenKey);
    if (_rememberMe && savedToken != null && savedToken.isNotEmpty) {
      _status = SessionStatus.authenticating;
      notifyListeners();

      await api.setAuthToken(savedToken);
      try {
        final user = await api.getCurrentUser().timeout(
              const Duration(seconds: 8),
            );
        if (user.isNotEmpty) {
          _currentUser = user;
          _sessionRevision++;
          _status = SessionStatus.authenticated;

          // Cache device_id from /system/info if not already in profile
          if (_profile.deviceId == null) {
            try {
              final info = await api.getSystemInfo();
              final devId = info?['device_id']?.toString();
              if (devId != null && devId.isNotEmpty) {
                _profile = _profile.copyWith(deviceId: devId);
                await _profile.save(prefs);
              }
            } catch (_) {}
          }

          notifyListeners();
          return;
        } else {
          // Empty user object received
          await clearSavedSession(prefs);
          await api.setAuthToken(null);
          _currentUser = null;
          _status = SessionStatus.unauthenticated;
          _lastError =
              'Thông tin người dùng không hợp lệ. Vui lòng đăng nhập lại.';
          notifyListeners();
          return;
        }
      } catch (e) {
        if (e is FireguardException && e.statusCode == 401) {
          // Token expired or invalid on server
          await clearSavedSession(prefs);
          await api.setAuthToken(null);
          _currentUser = null;
          _status = SessionStatus.sessionExpired;
          _lastError = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';
          notifyListeners();
          return;
        } else {
          // Network failure or temporary Pi unreachability
          await api.setAuthToken(null);
          _currentUser = null;
          _status = SessionStatus.unauthenticated;
          _lastError = e is FireguardException
              ? e.message
              : 'Không thể kết nối đến hệ thống FireGuard để xác thực phiên.';
          notifyListeners();
          return;
        }
      }
    } else if (!_rememberMe) {
      await clearSavedSession(prefs);
    }

    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> clearSavedSession([SharedPreferences? prefs]) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(prefSavedAuthTokenKey);
  }

  Future<void> setRememberMe(bool value, [SharedPreferences? prefs]) async {
    _rememberMe = value;
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setBool(prefRememberMeKey, value);
    if (!value) {
      await clearSavedSession(sp);
    } else if (api.authToken != null && api.authToken!.isNotEmpty) {
      await sp.setString(prefSavedAuthTokenKey, api.authToken!);
    }
    notifyListeners();
  }

  Future<bool> login({
    required String phoneNumber,
    required String secretKey,
    required String systemSecretKey,
    String deviceName = 'IGNIVO Mobile App',
    SharedPreferences? prefs,
    bool rememberMe = true,
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
      _rememberMe = rememberMe;

      // Persist session if rememberMe is enabled
      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setBool(prefRememberMeKey, rememberMe);
      if (rememberMe && api.authToken != null && api.authToken!.isNotEmpty) {
        await sp.setString(prefSavedAuthTokenKey, api.authToken!);
      } else {
        await sp.remove(prefSavedAuthTokenKey);
      }

      // Read device_id from /system/info if not already cached in profile
      if (_profile.deviceId == null) {
        try {
          final info = await api.getSystemInfo();
          final devId = info?['device_id']?.toString();
          if (devId != null && devId.isNotEmpty) {
            _profile = _profile.copyWith(deviceId: devId);
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

  Future<void> logout([SharedPreferences? prefs]) async {
    _sessionRevision++;
    try {
      await api.logout();
    } catch (_) {}
    await api.setAuthToken(null);
    _currentUser = null;
    final sp = prefs ?? await SharedPreferences.getInstance();
    await clearSavedSession(sp);
    _status = SessionStatus.unauthenticated;
    _lastError = null;
    notifyListeners();
  }

  Future<void> disconnect([SharedPreferences? prefs]) async {
    _sessionRevision++;
    try {
      await api.logout();
    } catch (_) {}
    await api.setAuthToken(null);
    _currentUser = null;
    _profile = PiConnectionProfile.createUnconfigured();
    final sp = prefs ?? await SharedPreferences.getInstance();
    await _profile.save(sp);
    await clearSavedSession(sp);
    _status = SessionStatus.unconfigured;
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
      await clearSavedSession(prefs);
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

  void handleSessionExpired([String? reason, SharedPreferences? prefs]) {
    if (_status == SessionStatus.sessionExpired) return;
    _sessionRevision++;
    api.setAuthToken(null);
    _currentUser = null;
    _status = SessionStatus.sessionExpired;
    _lastError = reason ??
        'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại để tiếp tục giám sát.';
    if (prefs != null) {
      prefs.remove(prefSavedAuthTokenKey);
    } else {
      SharedPreferences.getInstance().then((sp) => clearSavedSession(sp));
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
