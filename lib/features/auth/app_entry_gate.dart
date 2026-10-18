import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/system_session_controller.dart';
import '../../navigation/ignivo_shell.dart';
import '../settings/connection_setup_page.dart';
import 'ignivo_startup_view.dart';
import 'system_login_page.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({
    super.key,
    this.sessionController,
    this.authenticatedBuilder,
  });

  final SystemSessionController? sessionController;
  final Widget Function(BuildContext context, SystemSessionController controller)?
      authenticatedBuilder;

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  late final SystemSessionController _controller;
  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _controller = widget.sessionController ?? SystemSessionController();
    _controller.addListener(_onSessionChanged);
    _init();
  }

  Future<void> _init() async {
    setState(() => _initError = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await _controller.initialize(prefs);
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initError = 'Lỗi khởi tạo hệ thống: $e');
      }
    }
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onSessionChanged);
    if (widget.sessionController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return IgnivoStartupView(
        statusMessage: _controller.status == SessionStatus.authenticating
            ? 'Đang xác thực phiên đăng nhập...'
            : 'Đang kết nối hệ sinh thái IGNIVO...',
        errorMessage: _initError,
        onRetry: _initError != null ? _init : null,
      );
    }

    if (!_controller.isConfigured || _controller.status == SessionStatus.unconfigured) {
      return ConnectionSetupPage(
        sessionController: _controller,
        canPop: false,
      );
    }

    if (!_controller.isAuthenticated) {
      return SystemLoginPage(
        sessionController: _controller,
      );
    }

    // Authenticated: navigate to IgnivoShell
    if (widget.authenticatedBuilder != null) {
      return widget.authenticatedBuilder!(context, _controller);
    }

    return IgnivoShell(
      sessionController: _controller,
    );
  }
}
