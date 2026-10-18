import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/system_session_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video MJPEG Player
            Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: MjpegStreamView(
                  streamUrl: streamUrl,
                  fit: BoxFit.contain,
                  requestHeaders: widget.api.headersForUrl(streamUrl),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Camera Status Info Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOnline ? Icons.videocam : Icons.videocam_off,
                                color: isOnline ? Colors.green : Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isOnline
                                      ? 'Camera đang truyền phát'
                                      : 'Camera mất tín hiệu',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: isOnline ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(context, 'Khu vực lắp đặt', area),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            context,
                            'AI nhận diện cháy',
                            detectEnabled ? 'Đang kích hoạt' : 'Đã tạm tắt',
                            valueColor: detectEnabled
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            context,
                            'Tốc độ phân tích mục tiêu',
                            '$fps FPS',
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            context,
                            'Mã định danh camera',
                            'Camera #$id',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Maintenance & Edge Box Note
                  // Container(
                  //   padding: const EdgeInsets.all(14),
                  //   decoration: BoxDecoration(
                  //     color: theme.colorScheme.surfaceContainerHighest
                  //         .withValues(alpha: 0.4),
                  //     borderRadius: BorderRadius.circular(12),
                  //     border: Border.all(
                  //       color: theme.dividerColor.withValues(alpha: 0.1),
                  //     ),
                  //   ),
                  //   child: Row(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Icon(
                  //         Icons.info_outline,
                  //         size: 20,
                  //         color: theme.colorScheme.primary,
                  //       ),
                  //       const SizedBox(width: 10),
                  //       Expanded(
                  //         child: Text(
                  //           'Luồng MJPEG được phân tích trực tiếp tại chỗ bởi bộ tăng tốc Hailo NPU trên Raspberry Pi. Bất kỳ thay đổi vật lý hoặc đổi cổng RTSP cần thực hiện trên Edge Box.',
                  //           style: TextStyle(
                  //             fontSize: 12,
                  //             color: theme.textTheme.bodySmall?.color,
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
