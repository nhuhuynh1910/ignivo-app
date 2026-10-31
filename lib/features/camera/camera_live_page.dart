import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/fireeye_api_service.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_page_header.dart';
import '../fireguard/camera_editor_page.dart';
import 'mjpeg_stream_view.dart';

class CameraLivePage extends StatefulWidget {
  const CameraLivePage({
    super.key,
    required this.cameraId,
    required this.api,
    this.sessionController,
    this.initialCamera,
  });

  final int cameraId;
  final FireguardApiService api;
  final SystemSessionController? sessionController;
  final Map<String, dynamic>? initialCamera;

  @override
  State<CameraLivePage> createState() => _CameraLivePageState();
}

class _CameraLivePageState extends State<CameraLivePage> {
  Map<String, dynamic>? _camera;
  bool _isFullscreen = false;
  int _selectedTab = 0; // 0: Điều khiển PTZ, 1: Thông số & Trạng thái
  late final FireeyeApiService _eye;
  String? _activePtzAction;
  String? _ptzFeedback;

  @override
  void initState() {
    super.initState();
    _camera = widget.initialCamera;
    _eye = FireeyeApiService(fireguard: widget.api);
    _loadCameraDetail();
  }

  Future<void> _loadCameraDetail() async {
    try {
      final cameras = await widget.api.getCameras();
      final found = cameras.firstWhere(
        (c) => c['id'] == widget.cameraId,
        orElse: () => _camera ?? {'id': widget.cameraId},
      );
      if (mounted) {
        setState(() => _camera = found);
      }
    } catch (_) {}
  }

  void _openEditor() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GuardCameraEditor(
          api: widget.api,
          camera: _camera ?? {'id': widget.cameraId},
        ),
      ),
    );
    if (result == true) {
      _loadCameraDetail();
    }
  }

  void _handleSnapshot() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã ghi nhận ảnh chụp từ luồng camera trực tiếp.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang làm mới thông tin camera...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _loadCameraDetail();
  }

  Future<void> _handlePtzStart(String action) async {
    final canConfig =
        widget.sessionController?.isOwnerOrAdmin ?? widget.api.canConfigure;
    if (!canConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ Owner hoặc Admin mới có quyền điều khiển PTZ.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _activePtzAction = action;
      _ptzFeedback = 'Đang di chuyển: ${_getPtzActionLabel(action)}';
    });

    try {
      if (action.startsWith('zone-')) {
        final zoneId = int.tryParse(action.replaceFirst('zone-', '')) ?? 1;
        await _eye.gotoCameraZone(zoneId);
      } else {
        await _eye.moveCamera(action);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ptzFeedback = 'Lỗi kết nối PTZ: $e');
      }
    }
  }

  Future<void> _handlePtzStop(String action) async {
    final canConfig =
        widget.sessionController?.isOwnerOrAdmin ?? widget.api.canConfigure;
    if (!canConfig) return;

    setState(() => _activePtzAction = null);

    try {
      await _eye.stopCamera(action);
      if (mounted) {
        setState(() => _ptzFeedback = 'Đã dừng quay camera');
      }
    } catch (_) {}
  }

  String _getPtzActionLabel(String action) {
    switch (action) {
      case 'up':
        return 'Hướng lên';
      case 'down':
        return 'Hướng xuống';
      case 'left':
        return 'Xoay sang trái';
      case 'right':
        return 'Xoay sang phải';
      case 'zoom-in':
        return 'Phóng to (+ Zoom)';
      case 'zoom-out':
        return 'Thu nhỏ (- Zoom)';
      case 'home':
        return 'Vị trí Home';
      default:
        if (action.startsWith('zone-')) {
          return 'Chuyển ${action.replaceFirst('zone-', 'Khu vực ')}';
        }
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cam = _camera ?? widget.initialCamera ?? {};
    final id = widget.cameraId;
    final name = cam['name']?.toString() ?? 'Camera #$id';
    final area = cam['area']?.toString() ?? 'Chưa xác định khu vực';
    final statusMap = cam['status'] is Map ? (cam['status'] as Map) : null;
    final isOnline = statusMap?['online'] == true;
    final detectEnabled = cam['detect_enabled'] != false;
    final fpsVal = statusMap?['ai_fps'] ?? cam['ai_fps'];
    final dynamic fps = (fpsVal is num)
        ? (fpsVal == fpsVal.roundToDouble() ? fpsVal.toInt() : fpsVal)
        : (int.tryParse(fpsVal?.toString() ?? '') ?? 8);
    final streamUrl = widget.api.getMjpegStreamUrl(id);
    final canConfig =
        widget.sessionController?.isOwnerOrAdmin ?? widget.api.canConfigure;

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: MjpegStreamView(
                streamUrl: streamUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                requestHeaders: widget.api.headersForUrl(streamUrl),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Thoát toàn màn hình',
                        onPressed: () => setState(() => _isFullscreen = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$name ($area)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isOnline
                                  ? BrandTokens.stitchSafe
                                  : BrandTokens.stitchCritical)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? BrandTokens.stitchSafe
                                  : BrandTokens.stitchCritical,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'LIVE' : 'OFFLINE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? BrandTokens.darkBackground : BrandTokens.background,
      appBar: ignivoDetailAppBar(
        context,
        title: name,
        subtitle: area,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Toàn màn hình',
            onPressed: () => setState(() => _isFullscreen = true),
          ),
          if (canConfig)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Sửa cấu hình',
              onPressed: _openEditor,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Video Container with HUD Overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(
                      color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                      width: 1.2,
                    ),
                    boxShadow: BrandTokens.softShadow(isDark: isDark),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MjpegStreamView(
                          streamUrl: streamUrl,
                          fit: BoxFit.contain,
                          requestHeaders: widget.api.headersForUrl(streamUrl),
                        ),
                        // Soft gradient top and bottom for readability
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.45),
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                  stops: const [0.0, 0.22, 0.78, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Top-left: Live status pill
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius:
                                  BorderRadius.circular(BrandTokens.badgeRadius),
                              border: Border.all(
                                color: (isOnline
                                        ? BrandTokens.stitchSafe
                                        : BrandTokens.stitchCritical)
                                    .withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? BrandTokens.stitchSafe
                                        : BrandTokens.stitchCritical,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isOnline
                                                ? BrandTokens.stitchSafe
                                                : BrandTokens.stitchCritical)
                                            .withValues(alpha: 0.8),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOnline ? 'TRỰC TIẾP' : 'MẤT KẾT NỐI',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Top-right: FPS badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius:
                                  BorderRadius.circular(BrandTokens.badgeRadius),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.speed_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$fps FPS',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bottom watermark: Area & camera identity
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.place_rounded,
                                        color: BrandTokens.brandAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          area,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'CAM #$id',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Quick Action Toolbar
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildToolbarButton(
                      context: context,
                      icon: Icons.camera_alt_outlined,
                      label: 'Chụp ảnh',
                      onTap: _handleSnapshot,
                    ),
                    _buildToolbarButton(
                      context: context,
                      icon: Icons.refresh_rounded,
                      label: 'Làm mới',
                      onTap: _handleRefresh,
                    ),
                    _buildToolbarButton(
                      context: context,
                      icon: Icons.open_in_full_rounded,
                      label: 'Toàn màn hình',
                      onTap: () => setState(() => _isFullscreen = true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Segmented Navigation Tabs: [ Điều khiển PTZ ] | [ Thông số & Trạng thái ]
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text(
                        'Điều khiển PTZ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      icon: Icon(Icons.videogame_asset_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(
                        'Thông số & Trạng thái',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      icon: Icon(Icons.analytics_outlined, size: 18),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (s) => setState(() => _selectedTab = s.first),
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Tab Content: PTZ Joypad (Tab 0) OR Status Cards (Tab 1)
                if (_selectedTab == 0)
                  _buildPtzPanel(
                    context: context,
                    isDark: isDark,
                    canConfig: canConfig,
                  )
                else
                  _buildStatusPanel(
                    context: context,
                    isDark: isDark,
                    isOnline: isOnline,
                    area: area,
                    detectEnabled: detectEnabled,
                    fps: fps,
                    id: id,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 0: PTZ CONTROLLER PANEL ---
  Widget _buildPtzPanel({
    required BuildContext context,
    required bool isDark,
    required bool canConfig,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canConfig)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tài khoản đang đăng nhập chỉ có quyền xem. Cần quyền OWNER/ADMIN để xoay camera.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Joypad & Zoom Container Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            ),
            boxShadow: BrandTokens.softShadow(isDark: isDark),
          ),
          child: Column(
            children: [
              if (_ptzFeedback != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _ptzFeedback!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Joypad 4-direction control
                  _buildJoypad(context, isDark, canConfig),

                  // Divider
                  Container(
                    height: 140,
                    width: 1,
                    color: (isDark ? BrandTokens.darkBorder : BrandTokens.border)
                        .withValues(alpha: 0.7),
                  ),

                  // Zoom Controls Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ZOOM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? BrandTokens.darkTextTertiary
                              : BrandTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildZoomButton(
                        icon: Icons.zoom_in_rounded,
                        label: 'Phóng to',
                        action: 'zoom-in',
                        isDark: isDark,
                        enabled: canConfig,
                      ),
                      const SizedBox(height: 12),
                      _buildZoomButton(
                        icon: Icons.zoom_out_rounded,
                        label: 'Thu nhỏ',
                        action: 'zoom-out',
                        isDark: isDark,
                        enabled: canConfig,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Preset Zones Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            ),
            boxShadow: BrandTokens.softShadow(isDark: isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 18,
                    color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Vị trí quan sát cài sẵn (Preset Zones)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildZoneChip(1, 'Khu vực 1 (Bếp)', Icons.kitchen_rounded, isDark, canConfig),
                  _buildZoneChip(2, 'Khu vực 2 (Cửa chính)', Icons.door_front_door_rounded, isDark, canConfig),
                  _buildZoneChip(3, 'Khu vực 3 (Sân sau)', Icons.yard_rounded, isDark, canConfig),
                  _buildZoneChip(4, 'Khu vực 4 (Phòng khách)', Icons.weekend_rounded, isDark, canConfig),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoypad(BuildContext context, bool isDark, bool enabled) {
    final padBg = isDark ? BrandTokens.darkSurfaceVariant : Colors.grey.shade100;
    return Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        color: padBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // UP
          Positioned(
            top: 4,
            child: _buildDirectionArrow(
              icon: Icons.keyboard_arrow_up_rounded,
              action: 'up',
              tooltip: 'Lên trên',
              isDark: isDark,
              enabled: enabled,
            ),
          ),
          // DOWN
          Positioned(
            bottom: 4,
            child: _buildDirectionArrow(
              icon: Icons.keyboard_arrow_down_rounded,
              action: 'down',
              tooltip: 'Xuống dưới',
              isDark: isDark,
              enabled: enabled,
            ),
          ),
          // LEFT
          Positioned(
            left: 4,
            child: _buildDirectionArrow(
              icon: Icons.keyboard_arrow_left_rounded,
              action: 'left',
              tooltip: 'Sang trái',
              isDark: isDark,
              enabled: enabled,
            ),
          ),
          // RIGHT
          Positioned(
            right: 4,
            child: _buildDirectionArrow(
              icon: Icons.keyboard_arrow_right_rounded,
              action: 'right',
              tooltip: 'Sang phải',
              isDark: isDark,
              enabled: enabled,
            ),
          ),
          // CENTER HOME BUTTON
          GestureDetector(
            onTap: enabled ? () => _handlePtzStart('home') : null,
            child: Tooltip(
              message: 'Về góc quan sát mặc định (Home)',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _activePtzAction == 'home'
                      ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
                      : (isDark ? BrandTokens.darkSurface : Colors.white),
                  border: Border.all(
                    color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 22,
                  color: _activePtzAction == 'home'
                      ? Colors.white
                      : (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionArrow({
    required IconData icon,
    required String action,
    required String tooltip,
    required bool isDark,
    required bool enabled,
  }) {
    final isActive = _activePtzAction == action;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _handlePtzStart(action) : null,
        onTapUp: enabled ? (_) => _handlePtzStop(action) : null,
        onTapCancel: enabled ? () => _handlePtzStop(action) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
                : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 32,
            color: isActive
                ? Colors.white
                : (isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String label,
    required String action,
    required bool isDark,
    required bool enabled,
  }) {
    final isActive = _activePtzAction == action;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _handlePtzStart(action) : null,
      onTapUp: enabled ? (_) => _handlePtzStop(action) : null,
      onTapCancel: enabled ? () => _handlePtzStop(action) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
              : (isDark ? BrandTokens.darkSurfaceVariant : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
          border: Border.all(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? Colors.white
                  : (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? Colors.white
                    : (isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneChip(
    int zoneId,
    String label,
    IconData icon,
    bool isDark,
    bool enabled,
  ) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: enabled ? () => _handlePtzStart('zone-$zoneId') : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
      ),
      backgroundColor: isDark ? BrandTokens.darkSurfaceVariant : Colors.grey.shade50,
      side: BorderSide(
        color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
      ),
    );
  }

  // --- TAB 1: STATUS & TELEMETRY CARDS ---
  Widget _buildStatusPanel({
    required BuildContext context,
    required bool isDark,
    required bool isOnline,
    required String area,
    required bool detectEnabled,
    required dynamic fps,
    required dynamic id,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Overview Card
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            ),
            boxShadow: BrandTokens.softShadow(isDark: isDark),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isOnline
                          ? BrandTokens.stitchSafe
                          : BrandTokens.stitchCritical)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOnline
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  color: isOnline
                      ? BrandTokens.stitchSafe
                      : BrandTokens.stitchCritical,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline
                          ? 'Camera đang truyền phát'
                          : 'Camera mất tín hiệu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? BrandTokens.darkTextPrimary
                            : BrandTokens.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? 'Luồng MJPEG đang kết nối ổn định'
                          : 'Kiểm tra nguồn hoặc kết nối mạng camera',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? BrandTokens.darkTextTertiary
                            : BrandTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? (isDark
                          ? BrandTokens.stitchDarkOnlineBg
                          : BrandTokens.stitchOnlineBg)
                      : (isDark
                          ? BrandTokens.stitchDarkCriticalBg
                          : BrandTokens.stitchCriticalBg),
                  borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
                  border: Border.all(
                    color: isOnline
                        ? BrandTokens.stitchSafe.withValues(alpha: 0.3)
                        : BrandTokens.stitchCritical.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: isOnline
                        ? (isDark
                            ? BrandTokens.stitchDarkOnlineFg
                            : BrandTokens.stitchOnlineFg)
                        : (isDark
                            ? BrandTokens.stitchDarkCriticalFg
                            : BrandTokens.stitchCriticalFg),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metric 2x2 Grid
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.place_outlined,
                    iconColor: BrandTokens.brandAccent,
                    label: 'Khu vực lắp đặt',
                    value: area,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.auto_awesome_rounded,
                    iconColor: detectEnabled
                        ? BrandTokens.stitchSafe
                        : BrandTokens.stitchWarning,
                    label: 'AI nhận diện cháy',
                    value: detectEnabled ? 'Đang kích hoạt' : 'Đã tạm tắt',
                    valueColor: detectEnabled
                        ? BrandTokens.stitchSafe
                        : BrandTokens.stitchWarning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.speed_rounded,
                    iconColor: BrandTokens.brandSecondary,
                    label: 'Tốc độ phân tích mục tiêu',
                    value: '$fps FPS',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.fingerprint_rounded,
                    iconColor: isDark
                        ? BrandTokens.darkTextSecondary
                        : BrandTokens.textSecondary,
                    label: 'Mã định danh camera',
                    value: 'Camera #$id',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbarButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
      borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            ),
            boxShadow: BrandTokens.softShadow(isDark: isDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? BrandTokens.darkTextPrimary
                      : BrandTokens.brandNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ??
        (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: effectiveIconColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? BrandTokens.darkTextTertiary
                  : BrandTokens.textTertiary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ??
                  (isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
