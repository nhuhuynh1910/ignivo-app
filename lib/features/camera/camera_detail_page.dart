import 'package:flutter/material.dart';

import '../../core/services/camera_stream_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/camera_model.dart';
import '../../widgets/ptz_control.dart';
import 'live_view.dart';

class CameraDetailPage extends StatefulWidget {
  const CameraDetailPage({
    super.key,
    required this.camera,
  });

  final CameraModel camera;

  @override
  State<CameraDetailPage> createState() => _CameraDetailPageState();
}

class _CameraDetailPageState extends State<CameraDetailPage> {
  bool _isMuted = true;
  final StreamState _streamState = StreamState.live;

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: Text(
          camera.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // LIVE WEBRTC STREAMING VIEW
          LiveViewWidget(
            state: camera.online ? _streamState : StreamState.offline,
            snapshotUrl: camera.snapshotUrl,
          ),

          const SizedBox(height: 16),

          // CONTROL BAR: Audio, Snapshot, Fullscreen
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.backgroundBlueSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  label: _isMuted ? 'Âm thanh' : 'Bật',
                  enabled: camera.supportsMic,
                  onTap: () => setState(() => _isMuted = !_isMuted),
                ),
                _ActionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Snapshot',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã chụp ảnh snapshot!')),
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.fullscreen_rounded,
                  label: 'Toàn màn hình',
                  onTap: () {},
                ),
                _ActionButton(
                  icon: Icons.history_rounded,
                  label: 'Xem lại',
                  enabled: camera.supportsPlayback,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // PTZ CONTROL (If camera.supportsPtz == true)
          if (camera.supportsPtz) ...[
            const Text(
              'Điều khiển xoay (PTZ)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: PtzControl(
                onDirectionPressed: (direction) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PTZ: $direction'),
                      duration: const Duration(milliseconds: 400),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // CAMERA INFO
          const Text(
            'Thông tin Camera',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _DetailRow(title: 'Tên Camera', value: camera.name),
                const Divider(height: 20),
                _DetailRow(title: 'Model', value: camera.model),
                const Divider(height: 20),
                _DetailRow(title: 'Stream ID', value: camera.streamId),
                const Divider(height: 20),
                _DetailRow(
                  title: 'Giám sát AI',
                  value: camera.aiMonitored ? 'Active (Hailo-8L)' : 'Tắt',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.enabled = true,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.textTertiary.withValues(alpha: 0.4);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
