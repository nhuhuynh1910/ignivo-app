import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/ptz_control.dart';
import '../../widgets/pulsing_status_dot.dart';
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

  @override
  void initState() {
    super.initState();
    _camera = widget.initialCamera;
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
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: BrandTokens.brandNavy,
        content: const Row(
          children: [
            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Đã ghi nhận ảnh chụp từ luồng camera trực tiếp.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: BrandTokens.brandPrimary,
        content: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Đang làm mới thông tin camera...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    _loadCameraDetail();
  }

  void _handlePtzCommand(String cmd) {
    if (!mounted) return;
    final label = switch (cmd.toUpperCase()) {
      'UP' => 'Xoay lên ↑',
      'DOWN' => 'Xoay xuống ↓',
      'LEFT' => 'Xoay trái ←',
      'RIGHT' => 'Xoay phải →',
      'CENTER' => 'Căn giữa (Reset)',
      'ZOOM_IN' || 'ZOOM-IN' => 'Phóng to (+)',
      'ZOOM_OUT' || 'ZOOM-OUT' => 'Thu nhỏ (-)',
      _ => 'Lệnh PTZ: $cmd',
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
        backgroundColor: BrandTokens.brandNavy,
        content: Row(
          children: [
            const Icon(Icons.center_focus_strong_rounded, color: BrandTokens.brandAccent, size: 20),
            const SizedBox(width: 10),
            Text('Đã thực hiện: $label', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cam = _camera ?? widget.initialCamera ?? {};
    final id = widget.cameraId;
    final name = cam['name']?.toString() ?? 'Camera #$id';
    final area = cam['area']?.toString() ?? 'Chưa xác định khu vực';
    final isOnline = (cam['status'] as Map?)?['online'] == true;
    final detectEnabled = cam['detect_enabled'] != false;
    final fps = cam['ai_fps'] ?? 8;
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
                          PulsingStatusDot(
                            color: isOnline
                                ? BrandTokens.stitchSafe
                                : BrandTokens.stitchCritical,
                            size: 7,
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 20 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (flex: 65) — Video Player & Quick Control Toolbar
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildVideoPlayer(
                                  isDark: isDark,
                                  isOnline: isOnline,
                                  fps: fps,
                                  area: area,
                                  id: id,
                                  streamUrl: streamUrl,
                                ),
                                const SizedBox(height: 16),
                                _buildQuickToolbar(
                                  context: context,
                                  canConfig: canConfig,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Right Column (flex: 35) — PTZ Control, Status & Telemetry Cards
                          Expanded(
                            flex: 35,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStatusOverviewCard(
                                  isDark: isDark,
                                  isOnline: isOnline,
                                ),
                                const SizedBox(height: 16),
                                _buildPtzCard(
                                  context: context,
                                  isDark: isDark,
                                  isOnline: isOnline,
                                ),
                                const SizedBox(height: 16),
                                _buildAiNpuCard(
                                  context: context,
                                  isDark: isDark,
                                  detectEnabled: detectEnabled,
                                  fps: fps,
                                ),
                                const SizedBox(height: 16),
                                _buildMetricGrid(
                                  context: context,
                                  area: area,
                                  id: id,
                                  detectEnabled: detectEnabled,
                                  fps: fps,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildVideoPlayer(
                            isDark: isDark,
                            isOnline: isOnline,
                            fps: fps,
                            area: area,
                            id: id,
                            streamUrl: streamUrl,
                          ),
                          const SizedBox(height: 14),
                          _buildQuickToolbar(
                            context: context,
                            canConfig: canConfig,
                          ),
                          const SizedBox(height: 16),
                          _buildStatusOverviewCard(
                            isDark: isDark,
                            isOnline: isOnline,
                          ),
                          const SizedBox(height: 14),
                          _buildPtzCard(
                            context: context,
                            isDark: isDark,
                            isOnline: isOnline,
                          ),
                          const SizedBox(height: 14),
                          _buildAiNpuCard(
                            context: context,
                            isDark: isDark,
                            detectEnabled: detectEnabled,
                            fps: fps,
                          ),
                          const SizedBox(height: 14),
                          _buildMetricGrid(
                            context: context,
                            area: area,
                            id: id,
                            detectEnabled: detectEnabled,
                            fps: fps,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayer({
    required bool isDark,
    required bool isOnline,
    required dynamic fps,
    required String area,
    required int id,
    required String streamUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark
              ? BrandTokens.darkBorder
              : BrandTokens.brandNavy.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: BrandTokens.brandNavy.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
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

            // Subtle Vignette Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.50),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.60),
                      ],
                      stops: const [0.0, 0.22, 0.78, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Top-left: Live status pill
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius:
                      BorderRadius.circular(BrandTokens.badgeRadius),
                  border: Border.all(
                    color: (isOnline
                            ? BrandTokens.stitchSafe
                            : BrandTokens.stitchCritical)
                        .withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulsingStatusDot(
                      color: isOnline
                          ? BrandTokens.stitchSafe
                          : BrandTokens.stitchCritical,
                      size: 8,
                      pulseSize: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'TRỰC TIẾP' : 'MẤT KẾT NỐI',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-right: FPS badge
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius:
                      BorderRadius.circular(BrandTokens.badgeRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      color: BrandTokens.brandAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
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
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
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
                                fontWeight: FontWeight.w600,
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
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CAM #$id',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildQuickToolbar({
    required BuildContext context,
    required bool canConfig,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
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
        if (canConfig)
          _buildToolbarButton(
            context: context,
            icon: Icons.settings_outlined,
            label: 'Cấu hình camera',
            onTap: _openEditor,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                color: isDark
                    ? BrandTokens.darkPrimary
                    : BrandTokens.brandPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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

  Widget _buildStatusOverviewCard({
    required bool isDark,
    required bool isOnline,
  }) {
    return Container(
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
    );
  }

  Widget _buildAiNpuCard({
    required BuildContext context,
    required bool isDark,
    required bool detectEnabled,
    required dynamic fps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BrandTokens.primaryGradient,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: BrandTokens.brandNavy.withValues(alpha: isDark ? 0.4 : 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bộ tăng tốc AI Hailo NPU',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detectEnabled
                      ? 'Nhận diện cháy chủ động: $fps FPS'
                      : 'AI nhận diện đã tạm dừng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              detectEnabled ? 'ACTIVE' : 'PAUSED',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid({
    required BuildContext context,
    required String area,
    required int id,
    required bool detectEnabled,
    required dynamic fps,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
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
              fontSize: 14,
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

  Widget _buildPtzCard({
    required BuildContext context,
    required bool isDark,
    required bool isOnline,
  }) {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BrandTokens.brandAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.open_with_rounded,
                  size: 18,
                  color: BrandTokens.brandAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Điều khiển PTZ & Zoom',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PtzControl(
            enabled: isOnline,
            onDirectionPressed: (direction) {
              _handlePtzCommand(direction);
            },
            onZoomIn: () {
              _handlePtzCommand('ZOOM_IN');
            },
            onZoomOut: () {
              _handlePtzCommand('ZOOM_OUT');
            },
          ),
        ],
      ),
    );
  }
}
