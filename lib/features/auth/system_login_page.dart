import 'package:flutter/material.dart';
import '../../core/services/system_session_controller.dart';
import '../settings/connection_setup_page.dart';

class SystemLoginPage extends StatefulWidget {
  const SystemLoginPage({
    super.key,
    required this.sessionController,
  });

  final SystemSessionController sessionController;

  @override
  State<SystemLoginPage> createState() => _SystemLoginPageState();
}

class _SystemLoginPageState extends State<SystemLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _secretController = TextEditingController();
  final _systemSecretController = TextEditingController();

  bool _obscureSecret = true;
  bool _obscureSystemSecret = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _secretController.dispose();
    _systemSecretController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    widget.sessionController.clearError();

    final success = await widget.sessionController.login(
      phoneNumber: _phoneController.text.trim(),
      secretKey: _secretController.text,
      systemSecretKey: _systemSecretController.text,
    );

    if (success && mounted) {
      // Clear password inputs from RAM immediately upon successful login
      _secretController.clear();
      _systemSecretController.clear();
    }
  }

  void _openSetupPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionSetupPage(
          sessionController: widget.sessionController,
          canPop: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.sessionController;
    final isAuthenticating = controller.status == SessionStatus.authenticating;
    final errorMessage = controller.lastError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Center(
                      child: Icon(
                        Icons.local_fire_department,
                        size: 64,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'IGNIVO',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: const Color(0xFFFF5722),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống giám sát và cảnh báo khẩn cấp',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Connection card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.home_work_outlined,
                            size: 28,
                            color: Color(0xFFFF5722),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.systemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  controller.guardUrl,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            key: const Key('change-connection-link'),
                            onPressed: isAuthenticating ? null : _openSetupPage,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Đổi kết nối'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error banner
                    if (errorMessage != null && errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Phone number
                    TextFormField(
                      key: const Key('phone'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      enabled: !isAuthenticating,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '0912345678',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password (secret_key)
                    TextFormField(
                      key: const Key('secret'),
                      controller: _secretController,
                      obscureText: _obscureSecret,
                      enabled: !isAuthenticating,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu tài khoản',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSecret
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureSecret = !_obscureSecret,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Vui lòng nhập mật khẩu tài khoản';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // System key (system_secret_key)
                    TextFormField(
                      key: const Key('system-secret'),
                      controller: _systemSecretController,
                      obscureText: _obscureSystemSecret,
                      enabled: !isAuthenticating,
                      decoration: InputDecoration(
                        labelText: 'Mã khóa hệ thống (System Key)',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSystemSecret
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureSystemSecret = !_obscureSystemSecret,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Vui lòng nhập mã khóa hệ thống';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    FilledButton(
                      key: const Key('login-submit-btn'),
                      onPressed: isAuthenticating ? null : _handleLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isAuthenticating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Đăng nhập hệ thống',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
