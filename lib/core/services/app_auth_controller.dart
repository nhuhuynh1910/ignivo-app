import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Controller quản lý trạng thái tài khoản Cloud (Firebase Auth)
/// Hỗ trợ kiểm thử độc lập thông qua việc tiêm mock hoặc thiết lập mock user.
class AppAuthController extends ChangeNotifier {
  AppAuthController({
    AuthService? authService,
    String? initialMockUid,
    String? initialMockEmail,
  })  : _authService = authService,
        _mockUid = initialMockUid,
        _mockEmail = initialMockEmail {
    if (_mockUid != null) {
      _isMockMode = true;
    } else {
      _initAuthListener();
    }
  }

  final AuthService? _authService;
  StreamSubscription<User?>? _authSubscription;
  bool _isMockMode = false;
  String? _mockUid;
  String? _mockEmail;
  String? _lastError;
  bool _isLoading = false;

  AuthService get _service => _authService ?? AuthService();

  void _initAuthListener() {
    try {
      _authSubscription = _service.authStateChanges.listen(
        (user) {
          notifyListeners();
        },
        onError: (e) {
          _lastError = '$e';
          notifyListeners();
        },
      );
    } catch (e) {
      // Trong môi trường test nếu Firebase chưa khởi tạo native channel
      debugPrint('AppAuthController auth listener notice: $e');
    }
  }

  /// UID của người dùng hiện tại
  String? get currentUid {
    if (_isMockMode) return _mockUid;
    try {
      return _service.currentUserId;
    } catch (_) {
      return null;
    }
  }

  /// Email của người dùng hiện tại
  String? get currentUserEmail {
    if (_isMockMode) return _mockEmail;
    try {
      return _service.currentUserEmail;
    } catch (_) {
      return null;
    }
  }

  /// Đối tượng Firebase User (nếu đang chạy trên nền Firebase thật)
  User? get currentUser {
    if (_isMockMode) return null;
    try {
      return _service.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Trạng thái đăng nhập tài khoản Cloud
  bool get isLoggedIn => currentUid != null && currentUid!.isNotEmpty;

  /// Đang trong quá trình đăng nhập/đăng ký
  bool get isLoading => _isLoading;

  /// Lỗi cuối cùng
  String? get lastError => _lastError;

  /// Thiết lập mock user phục vụ unit test không phụ thuộc Firebase
  void setMockUser({String? uid, String? email}) {
    _isMockMode = true;
    _mockUid = uid;
    _mockEmail = email;
    _lastError = null;
    notifyListeners();
  }

  /// Đăng nhập bằng Email và Password
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (_isMockMode) {
        _mockUid = 'mock_uid_${email.hashCode.abs()}';
        _mockEmail = email;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      await _service.login(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _lastError = e is FirebaseAuthException ? (e.message ?? e.code) : '$e';
      notifyListeners();
      return false;
    }
  }

  /// Đăng ký bằng Email và Password
  Future<bool> registerWithEmail(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (_isMockMode) {
        _mockUid = 'mock_uid_${email.hashCode.abs()}';
        _mockEmail = email;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      await _service.register(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _lastError = e is FirebaseAuthException ? (e.message ?? e.code) : '$e';
      notifyListeners();
      return false;
    }
  }

  /// Đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (_isMockMode) {
        _mockUid = 'mock_google_uid_123';
        _mockEmail = 'mock_google@ignivo.test';
        _isLoading = false;
        notifyListeners();
        return true;
      }

      await _service.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _lastError = e is FirebaseAuthException ? (e.message ?? e.code) : '$e';
      notifyListeners();
      return false;
    }
  }

  /// Gửi email đặt lại mật khẩu
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (!_isMockMode) {
        await _service.sendPasswordResetEmail(email: email);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _lastError = e is FirebaseAuthException ? (e.message ?? e.code) : '$e';
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất tài khoản Cloud
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isMockMode) {
        _mockUid = null;
        _mockEmail = null;
      } else {
        await _service.logout();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
