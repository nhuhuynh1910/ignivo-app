import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  bool _googleInitialized = false;

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      _auth.currentUser;

  String? get currentUserId =>
      _auth.currentUser?.uid;

  String? get currentUserEmail =>
      _auth.currentUser?.email;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // ============================================================
  // PROVIDER CHECK
  // ============================================================

  bool get isPasswordUser {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    return user.providerData.any(
          (provider) =>
      provider.providerId == 'password',
    );
  }

  bool get isGoogleUser {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    return user.providerData.any(
          (provider) =>
      provider.providerId == 'google.com',
    );
  }

  String get currentLoginProvider {
    if (isPasswordUser) {
      return 'password';
    }

    if (isGoogleUser) {
      return 'google';
    }

    return 'unknown';
  }

  // ============================================================
  // GOOGLE INITIALIZATION
  // ============================================================

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize();

    _googleInitialized = true;
  }

  // ============================================================
  // EMAIL / PASSWORD LOGIN
  // ============================================================

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<UserCredential> signInWithGoogle() async {
    await _initializeGoogleSignIn();

    final GoogleSignInAccount googleUser =
    await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final OAuthCredential credential =
    GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(
      credential,
    );
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    return _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message:
        'Không tìm thấy người dùng đang đăng nhập.',
      );
    }

    final email = user.email;

    if (email == null ||
        email.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'no-email',
        message:
        'Tài khoản hiện tại không có email.',
      );
    }

    final passwordProviderExists =
    user.providerData.any(
          (provider) =>
      provider.providerId == 'password',
    );

    if (!passwordProviderExists) {
      throw FirebaseAuthException(
        code: 'not-password-user',
        message:
        'Tài khoản này không sử dụng mật khẩu để đăng nhập.',
      );
    }

    final credential =
    EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    // Xác thực lại mật khẩu hiện tại.
    await user.reauthenticateWithCredential(
      credential,
    );

    // Sau khi xác thực thành công mới được đổi mật khẩu.
    await user.updatePassword(
      newPassword,
    );
  }

  // ============================================================
  // RELOAD USER
  // ============================================================

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _auth.signOut();

    try {
      await _initializeGoogleSignIn();

      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase đã logout thành công.
      // Không chặn logout nếu Google sign-out lỗi.
    }
  }
}