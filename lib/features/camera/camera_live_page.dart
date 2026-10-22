import 'package:flutter/material.dart';
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
                const SizedBox(height: 14),

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
                const SizedBox(height: 16),

                // 3. Status Overview Card
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
                          borderRadius:
                              BorderRadius.circular(BrandTokens.badgeRadius),
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

                // 4. Metric 2x2 Grid
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
                            value:
                                detectEnabled ? 'Đang kích hoạt' : 'Đã tạm tắt',
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
                const SizedBox(height: 16),

                // 5. Edge Box Telemetry / Hardware Card
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
                //     borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                //     border: Border.all(
                //       color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                //     ),
                //     boxShadow: BrandTokens.softShadow(isDark: isDark),
                //   ),
                //   child: Row(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Container(
                //         padding: const EdgeInsets.all(10),
                //         decoration: BoxDecoration(
                //           color: (isDark
                //                   ? BrandTokens.darkPrimary
                //                   : BrandTokens.brandPrimary)
                //               .withValues(alpha: 0.12),
                //           borderRadius: BorderRadius.circular(12),
                //         ),
                //         child: Icon(
                //           Icons.memory_rounded,
                //           size: 22,
                //           color: isDark
                //               ? BrandTokens.darkPrimary
                //               : BrandTokens.brandPrimary,
                //         ),
                //       ),
                //       const SizedBox(width: 14),
                //       Expanded(
                //         child: Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: [
                //             Row(
                //               children: [
                //                 Expanded(
                //                   child: Text(
                //                     'Bộ xử lý biên AI Edge NPU',
                //                     style: TextStyle(
                //                       fontSize: 14,
                //                       fontWeight: FontWeight.bold,
                //                       color: isDark
                //                           ? BrandTokens.darkTextPrimary
                //                           : BrandTokens.brandNavy,
                //                     ),
                //                   ),
                //                 ),
                //                 Container(
                //                   padding: const EdgeInsets.symmetric(
                //                     horizontal: 8,
                //                     vertical: 3,
                //                   ),
                //                   decoration: BoxDecoration(
                //                     color: BrandTokens.brandAccent
                //                         .withValues(alpha: 0.15),
                //                     borderRadius: BorderRadius.circular(6),
                //                     border: Border.all(
                //                       color: BrandTokens.brandAccent
                //                           .withValues(alpha: 0.3),
                //                     ),
                //                   ),
                //                   child: const Text(
                //                     'Hailo-8L',
                //                     style: TextStyle(
                //                       fontSize: 10,
                //                       fontWeight: FontWeight.bold,
                //                       color: BrandTokens.brandAccent,
                //                     ),
                //                   ),
                //                 ),
                //               ],
                //             ),
                //             const SizedBox(height: 6),
                //             Text(
                //               'Luồng MJPEG được phân tích thị giác trực tiếp tại chỗ bằng bộ tăng tốc Hailo NPU. Mọi thay đổi vật lý hoặc đổi cổng RTSP cần cấu hình trực tiếp trên Edge Box.',
                //               style: TextStyle(
                //                 fontSize: 12,
                //                 color: isDark
                //                     ? BrandTokens.darkTextSecondary
                //                     : BrandTokens.textSecondary,
                //                 height: 1.4,
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
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
