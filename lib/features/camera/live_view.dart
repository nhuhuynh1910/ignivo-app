import 'package:flutter/material.dart';

import '../../core/services/camera_stream_service.dart';
import '../../core/theme/app_theme.dart';
import 'mjpeg_stream_view.dart';

class LiveViewWidget extends StatelessWidget {
  const LiveViewWidget({
    super.key,
    required this.state,
    this.snapshotUrl,
    this.mjpegStreamUrl,
  });

  final StreamState state;
  final String? snapshotUrl;
  final String? mjpegStreamUrl;

  @override
  Widget build(BuildContext context) {
    // Nếu có luồng MJPEG trực tiếp từ FireGuard và camera online, phát MJPEG trực tiếp
    if (mjpegStreamUrl != null && mjpegStreamUrl!.isNotEmpty && state == StreamState.live) {
      return MjpegStreamView(
        streamUrl: mjpegStreamUrl!,
        width: double.infinity,
        height: 220,
      );
    }

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (snapshotUrl != null && snapshotUrl!.isNotEmpty)
              Image.network(
                snapshotUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),

            // State Overlay
            switch (state) {
              StreamState.connecting => Container(
                color: Colors.black87,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Đang kết nối luồng camera tới FireGuard...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),

              StreamState.reconnecting => Container(
                color: Colors.black87,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.warning),
                    SizedBox(height: 12),
                    Text(
                      'Đang kết nối lại luồng video...',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ],
                ),
              ),

              StreamState.offline => Container(
                color: Colors.black87,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'Camera đang Offline',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              StreamState.error => Container(
                color: Colors.black87,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'Không thể tải luồng video',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              StreamState.live => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}
