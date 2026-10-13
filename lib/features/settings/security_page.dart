import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({
    super.key,
  });

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController =
  TextEditingController();

  final _newPasswordController =
  TextEditingController();

  final _confirmPasswordController =
  TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  bool _loading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _authService.changePassword(
        currentPassword:
        _currentPasswordController.text,
        newPassword:
        _newPasswordController.text,
      );

      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 42,
            ),
            title: const Text(
              'Đổi mật khẩu thành công',
            ),
            content: const Text(
              'Mật khẩu IGNIVO của bạn đã được cập nhật.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Đóng',
                ),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _firebaseErrorMessage(e),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể đổi mật khẩu. Vui lòng thử lại.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendResetEmail() async {
    final email = _authService.currentUserEmail;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không tìm thấy email của tài khoản.',
          ),
        ),
      );

      return;
    }

    try {
      await _authService.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi email đặt lại mật khẩu đến $email',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Không thể gửi email đặt lại mật khẩu.',
          ),
        ),
      );
    }
  }

  String _firebaseErrorMessage(
      FirebaseAuthException e,
      ) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hiện tại không đúng.';

      case 'weak-password':
        return 'Mật khẩu mới chưa đủ mạnh.';

      case 'requires-recent-login':
        return 'Vui lòng đăng nhập lại trước khi đổi mật khẩu.';

      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';

      case 'network-request-failed':
        return 'Không có kết nối mạng.';

      case 'not-password-user':
        return 'Tài khoản này không sử dụng mật khẩu.';

      default:
        return e.message ??
            'Không thể đổi mật khẩu.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordUser =
        _authService.isPasswordUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Bảo mật',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SecurityHeader(
            isPasswordUser: isPasswordUser,
          ),

          const SizedBox(height: 20),

          if (isPasswordUser)
            _buildPasswordForm()
          else
            _buildGoogleAccountInfo(),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.backgroundBlueSoft,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Đổi mật khẩu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Nhập mật khẩu hiện tại để xác minh trước khi tạo mật khẩu mới.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textTertiary,
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller:
              _currentPasswordController,
              obscureText:
              _hideCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideCurrentPassword =
                      !_hideCurrentPassword;
                    });
                  },
                  icon: Icon(
                    _hideCurrentPassword
                        ? Icons
                        .visibility_off_outlined
                        : Icons
                        .visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null ||
                    value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu hiện tại';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller:
              _newPasswordController,
              obscureText:
              _hideNewPassword,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                prefixIcon: const Icon(
                  Icons.key_rounded,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideNewPassword =
                      !_hideNewPassword;
                    });
                  },
                  icon: Icon(
                    _hideNewPassword
                        ? Icons
                        .visibility_off_outlined
                        : Icons
                        .visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final password =
                    value ?? '';

                if (password.isEmpty) {
                  return 'Vui lòng nhập mật khẩu mới';
                }

                if (password.length < 8) {
                  return 'Mật khẩu phải có ít nhất 8 ký tự';
                }

                if (password ==
                    _currentPasswordController
                        .text) {
                  return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller:
              _confirmPasswordController,
              obscureText:
              _hideConfirmPassword,
              decoration: InputDecoration(
                labelText:
                'Xác nhận mật khẩu mới',
                prefixIcon: const Icon(
                  Icons.lock_reset_rounded,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideConfirmPassword =
                      !_hideConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons
                        .visibility_off_outlined
                        : Icons
                        .visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null ||
                    value.isEmpty) {
                  return 'Vui lòng xác nhận mật khẩu mới';
                }

                if (value !=
                    _newPasswordController
                        .text) {
                  return 'Mật khẩu xác nhận không khớp';
                }

                return null;
              },
            ),

            const SizedBox(height: 10),

            Align(
              alignment:
              Alignment.centerRight,
              child: TextButton(
                onPressed: _sendResetEmail,
                child: const Text(
                  'Quên mật khẩu hiện tại?',
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                _loading
                    ? null
                    : _changePassword,
                icon: _loading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .lock_reset_rounded,
                ),
                label: Text(
                  _loading
                      ? 'Đang cập nhật...'
                      : 'Đổi mật khẩu',
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleAccountInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:
          AppColors.backgroundBlueSoft,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 50,
            color: AppColors.primary,
          ),

          SizedBox(height: 14),

          Text(
            'Đăng nhập bằng Google',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color:
              AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Tài khoản này đang sử dụng Google để đăng nhập. Mật khẩu được quản lý bởi tài khoản Google của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.45,
              color:
              AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader({
    required this.isPasswordUser,
  });

  final bool isPasswordUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        AppColors.backgroundBlueSoft,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bảo mật tài khoản',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    color: AppColors
                        .textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isPasswordUser
                      ? 'Quản lý và thay đổi mật khẩu đăng nhập IGNIVO.'
                      : 'Tài khoản được xác thực thông qua Google.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors
                        .textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}