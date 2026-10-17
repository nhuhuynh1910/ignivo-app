import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../core/services/system_session_controller.dart';
import '../fireguard/camera_editor_page.dart';
import '../fireguard/monitoring_controller.dart';
import 'camera_live_page.dart';

class GuardCamerasPage extends StatelessWidget {
  const GuardCamerasPage({
    super.key,
    required this.monitoringController,
    required this.sessionController,
    this.onOpenLiveView,
  });

  final MonitoringController monitoringController;
  final SystemSessionController sessionController;
  final void Function(int cameraId)? onOpenLiveView;

  void _navigateToLive(BuildContext context, Map<String, dynamic> cam) {
    final id = cam['id'] as int? ?? 0;
    if (onOpenLiveView != null) {
      onOpenLiveView!(id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraLivePage(
            cameraId: id,
            api: monitoringController.api,
            sessionController: sessionController,
            initialCamera: cam,
          ),
        ),
      );
    }
  }

  void _openEditor(BuildContext context, Map<String, dynamic> cam) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            GuardCameraEditor(api: monitoringController.api, camera: cam),
      ),
    );
    if (result == true) {
      monitoringController.refresh();
    }
  }

  void _showAddCameraGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Thêm camera mới',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Để bảo đảm an toàn hệ thống và hiệu năng mô hình Hailo NPU, việc gán camera IP (RTSP) hoặc USB được cấu hình trực tiếp tại Edge Box (Raspberry Pi) qua cổng cục bộ.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sau khi thêm camera trên Pi, danh sách camera trên ứng dụng di động sẽ tự động đồng bộ.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đã hiểu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfig = sessionController.isOwnerOrAdmin;

    return ListenableBuilder(
      listenable: monitoringController,
      builder: (context, _) {
        final cameras = monitoringController.cameras;
        final totalCameras = cameras.length;
        final onlineCameras = cameras
            .where((c) => (c['status'] as Map?)?['online'] == true)
            .length;

        return IgnivoPageBody(
          header: IgnivoPageHeader(
            title: 'Camera',
            subtitle: monitoringController.stale
                ? 'Trạng thái camera chưa cập nhật'
                : totalCameras > 0
                ? '$onlineCameras/$totalCameras camera trực tuyến'
                : 'Chưa phát hiện camera kết nối',
            systemName: sessionController.systemName,
            showSync: true,
            updatedAt: monitoringController.updated,
            stale: monitoringController.stale,
            action: IgnivoHeaderAction(
              icon: Icons.help_outline,
              tooltip: 'Hướng dẫn thêm camera',
              onPressed: () => _showAddCameraGuide(context),
            ),
          ),
          child: RefreshIndicator(
            onRefresh: monitoringController.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (cameras.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.videocam_off_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có camera nào được cấu hình',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Các camera RTSP/USB được thiết lập trực tiếp trên Raspberry Pi Edge Box.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showAddCameraGuide(context),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('Xem hướng dẫn thiết lập'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cameras.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final cam = cameras[index];
                      final id = cam['id'] as int? ?? 0;
                      final name = cam['name']?.toString() ?? 'Camera #$id';
                      final area = cam['area']?.toString() ?? 'Chưa xác định';
                      final isOnline =
                          (cam['status'] as Map?)?['online'] == true;
                      final detectEnabled = cam['detect_enabled'] != false;
                      final fps = cam['ai_fps'] ?? 8;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isOnline
                                ? theme.dividerColor.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.3),
                            width: isOnline ? 1 : 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isOnline
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    child: Icon(
                                      Icons.videocam,
                                      color: isOnline
                                          ? Colors.green
                                          : Colors.red,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Khu vực: $area',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
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
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      detectEnabled
                                          ? Icons.check_circle
                                          : Icons.pause_circle,
                                      size: 14,
                                      color: detectEnabled
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    label: Text(
                                      detectEnabled
                                          ? 'AI nhận diện: BẬT'
                                          : 'AI: TẮT',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.speed, size: 14),
                                    label: Text(
                                      '$fps FPS',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _navigateToLive(context, cam),
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Xem trực tiếp (Live View)',
                                      ),
                                    ),
                                  ),
                                  if (canConfig) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openEditor(context, cam),
                                      icon: const Icon(Icons.tune, size: 16),
                                      label: const Text('Sửa'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
