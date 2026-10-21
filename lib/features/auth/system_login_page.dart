import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../settings/connection_setup_page.dart';

import '../../core/services/system_session_manager.dart';

class SystemLoginPage extends StatefulWidget {
  const SystemLoginPage({
    super.key,
    required this.sessionController,
    this.sessionManager,
    this.onSwitchSystem,
    this.canPop,
    this.onBack,
  });

  final SystemSessionController sessionController;
  final SystemSessionManager? sessionManager;
  final VoidCallback? onSwitchSystem;
  final bool? canPop;
  final VoidCallback? onBack;

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
  late bool _rememberMe;

  @override
  void initState() {
    super.initState();
    _rememberMe = widget.sessionController.rememberMe;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _secretController.dispose();
    _systemSecretController.dispose();
    super.dispose();
  }

  bool get _canGoBack {
    if (widget.canPop != null) return widget.canPop!;
    if (widget.onBack != null) return true;
    return Navigator.canPop(context);
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else if (widget.onSwitchSystem != null) {
      widget.onSwitchSystem!();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    widget.sessionController.clearError();

    final success = await widget.sessionController.login(
      phoneNumber: _phoneController.text.trim(),
      secretKey: _secretController.text,
      systemSecretKey: _systemSecretController.text,
      rememberMe: _rememberMe,
    );

    if (success && mounted) {
      // Clear password inputs from RAM immediately upon successful login
      _secretController.clear();
      _systemSecretController.clear();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _openSetupPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionSetupPage(
          sessionController: widget.sessionController,
          sessionManager: widget.sessionManager,
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
    final showBack = _canGoBack;

    return Scaffold(
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                key: const Key('system-login-back-btn'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: 'Trở về danh sách hệ thống',
                onPressed: _handleBack,
              ),
            )
          : null,
      body: SafeArea(
        top: !showBack,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    const IgnivoAuthHeader(
                      title: 'Đăng nhập',
                      subtitle: 'Truy cập hệ thống giám sát của bạn',
                    ),
                    const SizedBox(height: 16),

                    // Connection card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(
                          BrandTokens.cardRadius,
                        ),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 28,
                            color: theme.colorScheme.primary,
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onSwitchSystem != null)
                                TextButton(
                                  key: const Key('switch-system-link'),
                                  onPressed: isAuthenticating ? null : widget.onSwitchSystem,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  child: const Text('Đổi hệ thống'),
                                ),
                              TextButton(
                                key: const Key('change-connection-link'),
                                onPressed: isAuthenticating ? null : _openSetupPage,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text('Đổi kết nối'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Error banner
                    if (errorMessage != null && errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(BrandTokens.space12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? BrandTokens.darkCriticalBg
                              : BrandTokens.criticalBg,
                          borderRadius: BorderRadius.circular(
                            BrandTokens.inputRadius,
                          ),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? BrandTokens.darkCriticalBorder
                                : BrandTokens.criticalBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.brightness == Brightness.dark
                                  ? BrandTokens.darkCriticalFg
                                  : BrandTokens.criticalFg,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.brightness == Brightness.dark
                                      ? BrandTokens.darkCriticalFg
                                      : BrandTokens.criticalFg,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
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
                    const SizedBox(height: 12),

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
                          onPressed: () =>
                              setState(() => _obscureSecret = !_obscureSecret),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Vui lòng nhập mật khẩu tài khoản';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 12),

                    // Remember me option
                    InkWell(
                      key: const Key('remember-me-toggle'),
                      borderRadius: BorderRadius.circular(BrandTokens.space8),
                      onTap: isAuthenticating
                          ? null
                          : () => setState(() => _rememberMe = !_rememberMe),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                key: const Key('remember-me-checkbox'),
                                value: _rememberMe,
                                onChanged: isAuthenticating
                                    ? null
                                    : (val) => setState(
                                          () => _rememberMe = val ?? false,
                                        ),
                                activeColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ghi nhớ đăng nhập trên thiết bị này',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
