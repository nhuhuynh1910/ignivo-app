import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/camera_snapshot_loader.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/camera_preview_card.dart';
import '../../widgets/camera_status_filters.dart';
import '../../widgets/ignivo_page_header.dart';
import '../fireguard/camera_editor_page.dart';
import '../fireguard/monitoring_controller.dart';
import 'camera_live_page.dart';

class GuardCamerasPage extends StatefulWidget {
  const GuardCamerasPage({
    super.key,
    required this.monitoringController,
    required this.sessionController,
    this.snapshotLoader,
    this.onOpenLiveView,
  });

  final MonitoringController monitoringController;
  final SystemSessionController sessionController;
  final CameraSnapshotLoader? snapshotLoader;
  final void Function(int cameraId)? onOpenLiveView;

  @override
  State<GuardCamerasPage> createState() => _GuardCamerasPageState();
}

class _GuardCamerasPageState extends State<GuardCamerasPage> {
  CameraFilterCategory _selectedFilter = CameraFilterCategory.all;
  late final CameraSnapshotLoader _snapshotLoader;
  bool _createdLoaderInternally = false;
  final Map<int, Uint8List> _snapshots = {};
  final Set<int> _attemptedSnapshots = {};
  final Set<int> _loadingSnapshots = {};

  @override
  void initState() {
    super.initState();
    if (widget.snapshotLoader != null) {
      _snapshotLoader = widget.snapshotLoader!;
    } else {
      _snapshotLoader = CameraSnapshotLoader(
        api: widget.monitoringController.api,
      );
      _createdLoaderInternally = true;
    }
  }

  @override
  void dispose() {
    if (_createdLoaderInternally) {
      _snapshotLoader.dispose();
    }
    super.dispose();
  }

  void _loadSnapshotForCamera(int id) {
    if (_attemptedSnapshots.contains(id) || _loadingSnapshots.contains(id)) return;
    _loadingSnapshots.add(id);
    _attemptedSnapshots.add(id);

    _snapshotLoader.loadSnapshot(id).then((result) {
      if (!mounted) return;
      setState(() {
        _loadingSnapshots.remove(id);
        if (result.isSuccess) {
          _snapshots[id] = result.bytes!;
        }
      });
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _loadingSnapshots.remove(id);
        });
      }
    });
  }

  void _navigateToLive(BuildContext context, Map<String, dynamic> cam) {
    final id = cam['id'] as int? ?? 0;
    if (widget.onOpenLiveView != null) {
      widget.onOpenLiveView!(id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraLivePage(
            cameraId: id,
            api: widget.monitoringController.api,
            sessionController: widget.sessionController,
            initialCamera: cam,
          ),
        ),
      );
    }
  }

  void _openEditor(BuildContext context, Map<String, dynamic> cam) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GuardCameraEditor(
          api: widget.monitoringController.api,
          camera: cam,
        ),
      ),
    );
    if (result == true) {
      _snapshotLoader.incrementGeneration();
      _snapshots.clear();
      _attemptedSnapshots.clear();
      _loadingSnapshots.clear();
      widget.monitoringController.refresh();
    }
  }

  void _showAddCameraGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BrandTokens.brandAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.videocam_outlined,
                        color: BrandTokens.brandAccent,
                        size: 24,
                      ),
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
                Text(
                  'Sau khi thêm camera trên Pi, danh sách camera trên ứng dụng di động sẽ tự động đồng bộ.',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                      ),
                    ),
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
    final canConfig = widget.sessionController.isOwnerOrAdmin;

    return ListenableBuilder(
      listenable: widget.monitoringController,
      builder: (context, _) {
        final cameras = widget.monitoringController.cameras;
        final totalCameras = cameras.length;
        final onlineCameras = cameras
            .where((c) => (c['status'] as Map?)?['online'] == true)
            .length;
        final offlineCameras = cameras
            .where((c) => (c['status'] as Map?)?['online'] == false)
            .length;
        final unknownCameras = cameras
            .where((c) => (c['status'] as Map?)?['online'] == null)
            .length;

        // Lọc danh sách theo filter đã chọn
        final filteredCameras = cameras.where((c) {
          final online = (c['status'] as Map?)?['online'];
          switch (_selectedFilter) {
            case CameraFilterCategory.all:
              return true;
            case CameraFilterCategory.online:
              return online == true;
            case CameraFilterCategory.offline:
              return online == false;
            case CameraFilterCategory.unknown:
              return online == null;
          }
        }).toList();

        final userName = widget.sessionController.fullName ?? 'Quản trị viên';
        final initials = userName
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join('')
            .toUpperCase();

        return IgnivoPageBody(
          header: IgnivoPageHeader(
            title: 'Camera',
            subtitle: widget.monitoringController.stale
                ? 'Trạng thái camera chưa cập nhật'
                : totalCameras > 0
                ? '$onlineCameras/$totalCameras camera trực tuyến'
                : 'Chưa phát hiện camera kết nối',
            systemName: widget.sessionController.systemName,
            avatarInitials: initials.isNotEmpty ? initials : 'MA',
            showSync: true,
            updatedAt: widget.monitoringController.updated,
            stale: widget.monitoringController.stale,
            action: IgnivoHeaderAction(
              icon: Icons.help_outline,
              tooltip: 'Hướng dẫn thêm camera',
              onPressed: () => _showAddCameraGuide(context),
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              _snapshotLoader.clearCache();
              _snapshots.clear();
              _attemptedSnapshots.clear();
              _loadingSnapshots.clear();
              await widget.monitoringController.refresh();
            },
            child: CustomScrollView(
              cacheExtent: 2000,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Thanh chip lọc trạng thái Stitch
                if (cameras.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 12),
                      child: CameraStatusFilters(
                        selected: _selectedFilter,
                        onSelected: (cat) => setState(() => _selectedFilter = cat),
                        totalCount: totalCameras,
                        onlineCount: onlineCameras,
                        offlineCount: offlineCameras,
                        unknownCount: unknownCameras,
                      ),
                    ),
                  ),

                // 2. Nội dung danh sách
                if (cameras.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
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
                    ),
                  )
                else if (filteredCameras.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'Không có camera nào phù hợp bộ lọc',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(
                                () => _selectedFilter = CameraFilterCategory.all,
                              ),
                              child: const Text('Xem tất cả'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (MediaQuery.of(context).size.width >= 900)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 480,
                        mainAxisExtent: 390,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildCameraCard(
                          context,
                          filteredCameras[index],
                          canConfig,
                        ),
                        childCount: filteredCameras.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: filteredCameras.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCameraCard(
                        context,
                        filteredCameras[index],
                        canConfig,
                      ),
                    ),
                  ),

                // 3. Hướng dẫn đồng bộ ở cuối
                // SliverToBoxAdapter(
                //   child: Padding(
                //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                //     child: Text(
                //       'Camera được cấu hình tại Raspberry Pi Edge Box và tự động đồng bộ.',
                //       textAlign: TextAlign.center,
                //       style: TextStyle(
                //         fontSize: 12,
                //         color: Theme.of(context).textTheme.bodySmall?.color,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraCard(
    BuildContext context,
    Map<String, dynamic> cam,
    bool canConfig,
  ) {
    final id = cam['id'] as int? ?? 0;
    final name = cam['name']?.toString() ?? 'Camera #$id';
    final area = cam['area']?.toString() ?? 'Chưa xác định';
    final isOnline = (cam['status'] as Map?)?['online'] as bool?;
    final detectConfig = cam['detect_enabled'] as bool?;
    final statusMap = cam['status'] as Map?;
    final fpsVal = statusMap?['ai_fps'] ?? cam['ai_fps'];
    final fps = (fpsVal is num && fpsVal > 0) ? fpsVal.toDouble() : null;

    // Kích hoạt nạp snapshot nếu chưa có sau frame
    if (!_attemptedSnapshots.contains(id) &&
        !_loadingSnapshots.contains(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSnapshotForCamera(id);
      });
    }

    final String aiLabel;
    final bool aiActive;
    if (detectConfig == false) {
      aiLabel = 'AI: TẮT';
      aiActive = false;
    } else if (isOnline == false) {
      aiLabel = 'AI: Ngoại tuyến';
      aiActive = false;
    } else if (detectConfig == true) {
      aiLabel = 'AI nhận diện: BẬT';
      aiActive = true;
    } else {
      aiLabel = 'AI: Chưa rõ';
      aiActive = false;
    }

    return CameraPreviewCard(
      name: name,
      area: area,
      model: cam['model']?.toString(),
      isOnline: isOnline,
      aiEnabled: aiActive,
      aiStatusText: aiLabel,
      aiFps: fps,
      snapshotBytes: _snapshots[id],
      isSnapshotLoading: _loadingSnapshots.contains(id),
      snapshotTime: _snapshots[id] != null ? 'Vừa xong' : null,
      canConfigure: canConfig,
      onTap: () => _navigateToLive(context, cam),
      onEdit: () => _openEditor(context, cam),
    );
  }
}
