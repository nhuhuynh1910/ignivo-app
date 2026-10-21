import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/app_auth_controller.dart';
import '../../core/services/multi_system_monitoring_coordinator.dart';
import '../../core/services/system_registry_repository.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/services/system_session_manager.dart';
import '../../navigation/ignivo_shell.dart';
import '../settings/connection_setup_page.dart';
import '../systems/systems_page.dart';
import 'ignivo_startup_view.dart';
import 'login_page.dart';
import 'system_login_page.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({
    super.key,
    this.sessionController,
    this.authController,
    this.sessionManager,
    this.registryRepository,
    this.coordinator,
    this.authenticatedBuilder,
  });

  final SystemSessionController? sessionController;
  final AppAuthController? authController;
  final SystemSessionManager? sessionManager;
  final SystemRegistryRepository? registryRepository;
  final MultiSystemMonitoringCoordinator? coordinator;
  final Widget Function(BuildContext context, SystemSessionController controller)?
      authenticatedBuilder;

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  // Legacy single controller mode
  SystemSessionController? _legacyController;
  bool _legacyInitialized = false;
  String? _legacyInitError;

  // Account-First multi-system mode
  late final AppAuthController _authController;
  late final SystemRegistryRepository _registry;
  SystemSessionManager? _sessionManager;
  MultiSystemMonitoringCoordinator? _coordinator;
  bool _managerInitialized = false;
  String? _managerError;

  bool get _isLegacyMode {
    if (widget.authController != null) return false;
    if (widget.sessionController != null) return true;
    try {
      if (Firebase.apps.isEmpty) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_isLegacyMode) {
      _initLegacyMode();
    } else {
      _initAccountFirstMode();
    }
  }

  void _initLegacyMode() {
    _legacyController = widget.sessionController ?? SystemSessionController();
    _legacyController!.addListener(_onSessionChanged);
    _initLegacySession();
  }

  Future<void> _initLegacySession() async {
    setState(() => _legacyInitError = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await _legacyController!.initialize(prefs);
      if (mounted) {
        setState(() => _legacyInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _legacyInitError = 'Lỗi khởi tạo hệ thống: $e');
      }
    }
  }

  void _initAccountFirstMode() {
    _authController = widget.authController ?? AppAuthController();
    _registry = widget.registryRepository ?? SystemRegistryRepository();
    _authController.addListener(_onAuthChanged);

    if (_authController.isLoggedIn) {
      _initManagerForUser(_authController.currentUid!);
    }
  }

  Future<void> _initManagerForUser(String uid) async {
    setState(() {
      _managerInitialized = false;
      _managerError = null;
    });

    try {
      // Tự động di chuyển profile cũ từ SharedPreferences sang UID nếu có
      await _registry.migrateLegacyProfile(uid);

      if (widget.sessionManager != null && widget.sessionManager!.uid == uid) {
        _sessionManager = widget.sessionManager!;
      } else {
        _sessionManager?.dispose();
        _sessionManager = SystemSessionManager(
          registry: _registry,
          uid: uid,
        );
      }

      await _sessionManager!.initialize();
      _sessionManager!.addListener(_onSessionChanged);

      _coordinator?.dispose();
      _coordinator = widget.coordinator ??
          MultiSystemMonitoringCoordinator(sessionManager: _sessionManager!);
      _coordinator!.start();

      if (mounted) {
        setState(() => _managerInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _managerError = 'Lỗi khởi tạo danh mục hệ thống: $e';
          _managerInitialized = true;
        });
      }
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_authController.isLoggedIn) {
      final uid = _authController.currentUid!;
      if (_sessionManager == null || _sessionManager!.uid != uid) {
        _initManagerForUser(uid);
      } else {
        setState(() {});
      }
    } else {
      _coordinator?.stop();
      _coordinator?.dispose();
      _coordinator = null;
      _sessionManager?.removeListener(_onSessionChanged);
      if (widget.sessionManager == null) {
        _sessionManager?.dispose();
      }
      _sessionManager = null;
      _managerInitialized = false;
      setState(() {});
    }
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_isLegacyMode) {
      _legacyController?.removeListener(_onSessionChanged);
      if (widget.sessionController == null) {
        _legacyController?.dispose();
      }
    } else {
      _authController.removeListener(_onAuthChanged);
      if (widget.authController == null) {
        _authController.dispose();
      }
      _coordinator?.dispose();
      _sessionManager?.removeListener(_onSessionChanged);
      if (widget.sessionManager == null) {
        _sessionManager?.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLegacyMode) {
      return _buildLegacyFlow(context);
    }
    return _buildAccountFirstFlow(context);
  }

  Widget _buildLegacyFlow(BuildContext context) {
    final controller = _legacyController!;
    if (!_legacyInitialized) {
      return IgnivoStartupView(
        statusMessage: controller.status == SessionStatus.authenticating
            ? 'Đang xác thực phiên đăng nhập...'
            : 'Đang kết nối hệ sinh thái IGNIVO...',
        errorMessage: _legacyInitError,
        onRetry: _legacyInitError != null ? _initLegacySession : null,
      );
    }

    if (!controller.isConfigured ||
        controller.status == SessionStatus.unconfigured) {
      return ConnectionSetupPage(
        sessionController: controller,
        canPop: false,
      );
    }

    if (!controller.isAuthenticated) {
      return SystemLoginPage(
        sessionController: controller,
      );
    }

    if (widget.authenticatedBuilder != null) {
      return widget.authenticatedBuilder!(context, controller);
    }

    return IgnivoShell(
      sessionController: controller,
    );
  }

  Widget _buildAccountFirstFlow(BuildContext context) {
    // 1. Chưa đăng nhập tài khoản Ignivo Cloud
    if (!_authController.isLoggedIn) {
      return LoginPage(
        authController: _authController,
      );
    }

    // 2. Đang khởi tạo session manager cho UID
    if (!_managerInitialized) {
      return IgnivoStartupView(
        statusMessage: 'Đang tải danh mục hệ thống...',
        errorMessage: _managerError,
        onRetry: _managerError != null && _authController.currentUid != null
            ? () => _initManagerForUser(_authController.currentUid!)
            : null,
      );
    }

    final manager = _sessionManager;
    if (widget.authenticatedBuilder != null && manager?.activeController != null) {
      return widget.authenticatedBuilder!(context, manager!.activeController!);
    }

    // Luồng chuẩn DMSS: Sau khi đăng nhập, màn hình chính là Device Hub (SystemsPage)
    return SystemsPage(
      sessionManager: manager ??
          SystemSessionManager(
            registry: _registry,
            uid: _authController.currentUid ?? '',
          ),
      authController: _authController,
      coordinator: _coordinator,
      canPop: false,
    );
  }
}
