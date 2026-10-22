import 'package:flutter/material.dart';
import '../../core/services/app_auth_controller.dart';
import '../systems/systems_page.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../settings/connection_setup_page.dart';

import '../../core/services/system_session_manager.dart';
import '../../core/models/system_record.dart';

class SystemLoginPage extends StatefulWidget {
  const SystemLoginPage({
    super.key,
    required this.sessionController,
    this.sessionManager,
    this.authController,
    this.onSwitchSystem,
    this.canPop,
    this.onBack,
  });

  final SystemSessionController sessionController;
  final SystemSessionManager? sessionManager;
  final AppAuthController? authController;
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

    final phoneInput = _phoneController.text.trim();
    var success = await widget.sessionController.login(
      phoneNumber: phoneInput,
      secretKey: _secretController.text,
      systemSecretKey: _systemSecretController.text,
      rememberMe: _rememberMe,
    );

    // Auto-retry with Vietnamese country code (+84) if user entered 0...
    if (!success && phoneInput.startsWith('0') && phoneInput.length >= 9) {
      final altPhone = '+84${phoneInput.substring(1)}';
      success = await widget.sessionController.login(
        phoneNumber: altPhone,
        secretKey: _secretController.text,
        systemSecretKey: _systemSecretController.text,
        rememberMe: _rememberMe,
      );
    }

    if (success && mounted) {
      if (widget.sessionManager != null &&
          widget.sessionController.api.authToken != null) {
        final token = widget.sessionController.api.authToken!;
        final systems = widget.sessionManager!.systems;
        final currentSys = systems.firstWhere(
          (s) => s.guardUrl == widget.sessionController.guardUrl,
          orElse: () => systems.isNotEmpty
              ? systems.first
              : SystemRecord.fromPiConnectionProfile(
                  widget.sessionController.profile,
                  systemId:
                      'sys_${widget.sessionController.guardUrl.hashCode.abs()}',
                ),
        );
        await widget.sessionManager!.registry.setSystemToken(
          widget.sessionManager!.uid,
          currentSys.systemId,
          token,
        );
      }

      // Clear password inputs from RAM immediately upon successful login
      _secretController.clear();
      _systemSecretController.clear();
      if (!mounted) return;
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

  void _openSystemsPage() {
    if (widget.onSwitchSystem != null) {
      widget.onSwitchSystem!();
    } else if (widget.sessionManager != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SystemsPage(
            sessionManager: widget.sessionManager!,
            authController: widget.authController,
            canPop: true,
          ),
        ),
      );
    }
  }

  Future<void> _confirmSignOutCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất tài khoản Cloud'),
        content: const Text(
          'Bạn có muốn đăng xuất khỏi tài khoản Ignivo Cloud hiện tại và quay về màn hình đăng nhập?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true && widget.authController != null) {
      await widget.authController!.signOut();
    }
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
              title: const Text('Đăng nhập hệ thống'),
            )
          : (widget.authController != null || widget.sessionManager != null
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: const Text('Đăng nhập hệ thống'),
                  actions: [
                    if (widget.sessionManager != null)
                      IconButton(
                        icon: const Icon(Icons.hub_outlined),
                        tooltip: 'Đổi hệ thống',
                        onPressed: isAuthenticating ? null : _openSystemsPage,
                      ),
                    if (widget.authController != null)
                      IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        tooltip: 'Đăng xuất tài khoản Cloud',
                        onPressed: isAuthenticating ? null : _confirmSignOutCloud,
                      ),
                  ],
                )
              : null),
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
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(
                          BrandTokens.cardRadius,
                        ),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? BrandTokens.darkBorder
                              : BrandTokens.border,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: BrandTokens.brandPrimary.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.home_work_outlined,
                            size: 26,
                            color: BrandTokens.brandAccent,
                          ),
                          const SizedBox(width: 10),
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
                              if (widget.onSwitchSystem != null ||
                                  (widget.sessionManager != null &&
                                      widget.sessionManager!.systems.length > 1))
                                TextButton(
                                  key: const Key('switch-system-link'),
                                  onPressed: isAuthenticating ? null : _openSystemsPage,
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
                        hintText: '+84999999999 hoặc 0999999999',
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
                        backgroundColor: BrandTokens.brandPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 2,
                        shadowColor: BrandTokens.brandPrimary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                        ),
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
                    const SizedBox(height: 8),

                    // Quick-fill helper button for default Pi credentials
                    Center(
                      child: TextButton.icon(
                        key: const Key('quick-fill-pi-btn'),
                        onPressed: isAuthenticating
                            ? null
                            : () {
                                _phoneController.text = '+84999999999';
                                _secretController.text = 'adminpassword';
                                _systemSecretController.text =
                                    'default_server_secret_key_123456';
                                setState(() {});
                              },
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        label: const Text(
                          'Điền tài khoản mẫu Pi (+84999999999 / Owner)',
                          style: TextStyle(fontSize: 12),
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
