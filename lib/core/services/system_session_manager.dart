import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/system_record.dart';
import 'fireguard_api_service.dart';
import 'system_registry_repository.dart';
import 'system_session_controller.dart';

typedef SessionControllerFactory = SystemSessionController Function(
  SystemRecord record, {
  String? savedToken,
});

/// Quản lý đồng thời các phiên làm việc (SystemSessionController) của nhiều Pi
/// cho một tài khoản Firebase UID cụ thể, đảm bảo cách ly tuyệt đối baseUrl và token.
class SystemSessionManager extends ChangeNotifier {
  SystemSessionManager({
    required this.registry,
    required this.uid,
    SessionControllerFactory? controllerFactory,
  }) : _controllerFactory = controllerFactory;

  final SystemRegistryRepository registry;
  final String uid;
  final SessionControllerFactory? _controllerFactory;

  final Map<String, SystemSessionController> _controllers = {};
  List<SystemRecord> _systems = [];
  String? _activeSystemId;
  bool _initialized = false;
  String? _lastError;
  bool _disposed = false;
  StreamSubscription<List<SystemRecord>>? _cloudSub;

  bool get isInitialized => _initialized;
  String? get activeSystemId => _activeSystemId;
  String? get lastError => _lastError;

  List<SystemRecord> get systems => List.unmodifiable(_systems);

  /// Controller của hệ thống đang hoạt động trên màn hình chính
  SystemSessionController? get activeController =>
      _activeSystemId != null ? _controllers[_activeSystemId] : null;

  /// Lấy controller của một hệ thống cụ thể
  SystemSessionController? getController(String systemId) => _controllers[systemId];

  /// Tất cả controllers đang quản lý
  Map<String, SystemSessionController> get allControllers =>
      Map.unmodifiable(_controllers);

  /// Khởi tạo và nạp toàn bộ danh mục hệ thống và phiên của UID
  Future<void> initialize() async {
    _lastError = null;
    try {
      _systems = await registry.getSystems(uid);

      // Dọn dẹp controllers cũ nếu có
      for (final c in _controllers.values) {
        c.removeListener(_onChildControllerChanged);
        c.dispose();
      }
      _controllers.clear();

      for (final system in _systems) {
        final token = await registry.getSystemToken(uid, system.systemId);
        final controller = _createController(system, savedToken: token);
        controller.addListener(_onChildControllerChanged);
        _controllers[system.systemId] = controller;
      }

      // Xác định active system
      final savedActiveId = await registry.getActiveSystemId(uid);
      if (savedActiveId != null && _controllers.containsKey(savedActiveId)) {
        _activeSystemId = savedActiveId;
      } else if (_systems.isNotEmpty) {
        _activeSystemId = _systems.first.systemId;
        await registry.setActiveSystemId(uid, _activeSystemId!);
      } else {
        _activeSystemId = null;
      }

      _initialized = true;
      notifyListeners();

      // Kích hoạt đồng bộ Cloud hai chiều để đồng bộ tức thì với các thiết bị khác (Web & App)
      if (registry.isCloudSyncSupported) {
        _startCloudSync();
      }
    } catch (e) {
      _lastError = 'Lỗi khởi tạo hệ thống: $e';
      _initialized = true;
      notifyListeners();
    }
  }

  void _startCloudSync() {
    if (!registry.isCloudSyncSupported) return;

    _cloudSub?.cancel();
    _cloudSub = registry.watchCloudSystems(uid).listen(
      (cloudList) {
        if (!_disposed) {
          _applySyncedSystems(cloudList);
        }
      },
      onError: (err) {
        debugPrint('Cloud systems watch note: $err');
      },
    );

    // Kéo dữ liệu từ Cloud về để hợp nhất với bộ nhớ cục bộ
    registry.syncFromCloud(uid).then((synced) {
      if (!_disposed) {
        _applySyncedSystems(synced);
      }
    }).catchError((err) {
      debugPrint('Cloud syncFromCloud note: $err');
    });
  }

  void _applySyncedSystems(List<SystemRecord> newSystems) async {
    if (_disposed || newSystems.isEmpty) return;

    final currentIds = _systems.map((s) => s.systemId).toSet();
    final newIds = newSystems.map((s) => s.systemId).toSet();

    final isDifferent = currentIds.length != newIds.length ||
        !currentIds.containsAll(newIds) ||
        _systems.any((s) {
          final match = newSystems.where((n) => n.systemId == s.systemId);
          if (match.isEmpty) return true;
          final n = match.first;
          return n.systemName != s.systemName || n.guardUrl != s.guardUrl;
        });

    if (!isDifferent || _disposed) return;

    _systems = List.unmodifiable(newSystems);

    // Bổ sung controller cho các hệ thống mới tải từ Cloud
    for (final sys in _systems) {
      if (!_controllers.containsKey(sys.systemId)) {
        final token = await registry.getSystemToken(uid, sys.systemId);
        final controller = _createController(sys, savedToken: token);
        controller.addListener(_onChildControllerChanged);
        _controllers[sys.systemId] = controller;
      }
    }

    // Dọn dẹp controller cho các hệ thống đã bị gỡ trên thiết bị khác
    final removedIds =
        _controllers.keys.where((id) => !newIds.contains(id)).toList();
    for (final id in removedIds) {
      final c = _controllers.remove(id);
      c?.removeListener(_onChildControllerChanged);
      c?.dispose();
    }

    // Đảm bảo active system luôn hợp lệ
    if (_activeSystemId == null || !_controllers.containsKey(_activeSystemId)) {
      _activeSystemId = _systems.isNotEmpty ? _systems.first.systemId : null;
      if (_activeSystemId != null) {
        await registry.setActiveSystemId(uid, _activeSystemId!);
      }
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  SystemSessionController _createController(
    SystemRecord system, {
    String? savedToken,
  }) {
    if (_controllerFactory != null) {
      return _controllerFactory(system, savedToken: savedToken);
    }

    final api = FireguardApiService();
    api.setBaseUrl(system.guardUrl);
    final profile = system.toPiConnectionProfile();
    final controller = SystemSessionController(
      api: api,
      initialProfile: profile,
    );

    // Nếu có token lưu trữ, nạp vào api và kiểm tra tính hợp lệ
    if (savedToken != null && savedToken.isNotEmpty) {
      api.setAuthToken(savedToken);
    }

    return controller;
  }

  void _onChildControllerChanged() {
    notifyListeners();
  }

  /// Chuyển đổi hệ thống đang thao tác chính
  Future<void> switchSystem(String systemId) async {
    if (_activeSystemId == systemId) return;
    if (!_controllers.containsKey(systemId)) {
      debugPrint('Cannot switch to unknown system: $systemId');
      return;
    }

    _activeSystemId = systemId;
    await registry.setActiveSystemId(uid, systemId);
    notifyListeners();
  }

  /// Thêm hoặc cập nhật một hệ thống
  Future<void> addOrUpdateSystem(
    SystemRecord system, {
    String? token,
    SystemSessionController? existingController,
  }) async {
    await registry.saveSystem(uid, system, token: token);
    _systems = await registry.getSystems(uid);

    if (_controllers.containsKey(system.systemId)) {
      // Cập nhật profile trên controller hiện có
      final controller = _controllers[system.systemId]!;
      if (token != null) {
        await controller.api.setAuthToken(token);
      }
    } else {
      final controller = existingController ??
          _createController(system, savedToken: token);
      controller.addListener(_onChildControllerChanged);
      _controllers[system.systemId] = controller;
    }

    if (_activeSystemId == null || _activeSystemId!.isEmpty) {
      _activeSystemId = system.systemId;
      await registry.setActiveSystemId(uid, _activeSystemId!);
    }

    notifyListeners();
  }

  /// Gỡ bỏ hệ thống khỏi tài khoản
  Future<void> removeSystem(String systemId) async {
    await registry.removeSystem(uid, systemId);
    _systems = await registry.getSystems(uid);

    final controller = _controllers.remove(systemId);
    if (controller != null) {
      controller.removeListener(_onChildControllerChanged);
      controller.dispose();
    }

    if (_activeSystemId == systemId) {
      _activeSystemId = _systems.isNotEmpty ? _systems.first.systemId : null;
      if (_activeSystemId != null) {
        await registry.setActiveSystemId(uid, _activeSystemId!);
      }
    }

    notifyListeners();
  }

  /// Đăng xuất khỏi hệ thống hiện tại mà không gỡ hệ thống khỏi danh mục
  Future<void> logoutSystem(String systemId) async {
    final controller = _controllers[systemId];
    if (controller != null) {
      await controller.logout();
    }
    await registry.setSystemToken(uid, systemId, null);
    notifyListeners();
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    for (final c in _controllers.values) {
      c.removeListener(_onChildControllerChanged);
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}
