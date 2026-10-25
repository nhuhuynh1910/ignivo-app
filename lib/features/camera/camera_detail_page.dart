import 'package:flutter/material.dart';

import '../../core/services/camera_stream_service.dart';
import '../../core/theme/brand_tokens.dart';
import '../../models/camera_model.dart';
import '../../widgets/ptz_control.dart';
import 'live_view.dart';

class CameraDetailPage extends StatefulWidget {
  const CameraDetailPage({super.key, required this.camera});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? BrandTokens.darkBackground : BrandTokens.background,
      appBar: AppBar(
        backgroundColor: isDark ? BrandTokens.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          camera.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // LIVE AI STREAMING VIEW
              LiveViewWidget(
                state: camera.online ? _streamState : StreamState.offline,
                snapshotUrl: camera.snapshotUrl,
              ),

              const SizedBox(height: 16),

              // ACTION CONTROL BAR: Audio, Snapshot, Fullscreen, Playback
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? BrandTokens.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  border: Border.all(
                    color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  ),
                  boxShadow: BrandTokens.softShadow(isDark: isDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      label: _isMuted ? 'Âm thanh' : 'Đang bật',
                      enabled: camera.supportsMic,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      isDark: isDark,
                    ),
                    _ActionButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Snapshot',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã chụp ảnh snapshot!'),
                            backgroundColor: BrandTokens.stitchSafe,
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    _ActionButton(
                      icon: Icons.fullscreen_rounded,
                      label: 'Toàn màn hình',
                      onTap: () {},
                      isDark: isDark,
                    ),
                    _ActionButton(
                      icon: Icons.history_rounded,
                      label: 'Xem lại',
                      enabled: camera.supportsPlayback,
                      onTap: () {},
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // PTZ CONTROL (With Zoom In & Zoom Out)
              if (camera.supportsPtz) ...[
                Text(
                  'BẢNG ĐIỀU KHIỂN XOAY & THU PHÓNG (PTZ)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.brandNavy,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(
                      color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                    ),
                    boxShadow: BrandTokens.softShadow(isDark: isDark),
                  ),
                  child: PtzControl(
                    onDirectionPressed: (direction) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('PTZ Command: $direction'),
                          duration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // CAMERA METADATA CARD
              Text(
                'THÔNG TIN CAMERA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.brandNavy,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? BrandTokens.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  border: Border.all(
                    color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  ),
                  boxShadow: BrandTokens.softShadow(isDark: isDark),
                ),
                child: Column(
                  children: [
                    _DetailRow(title: 'Tên Camera', value: camera.name, isDark: isDark),
                    const Divider(height: 24),
                    _DetailRow(title: 'Model', value: camera.model, isDark: isDark),
                    const Divider(height: 24),
                    _DetailRow(title: 'Stream ID', value: camera.streamId, isDark: isDark),
                    const Divider(height: 24),
                    _DetailRow(
                      title: 'Giám sát AI Local',
                      value: camera.aiMonitored ? 'Hailo-8L On-device Active' : 'Tắt',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy)
        : (isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary.withValues(alpha: 0.5));

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled
                    ? (isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint)
                    : (isDark ? BrandTokens.darkBackground : BrandTokens.background),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.title,
    required this.value,
    required this.isDark,
  });

  final String title;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}
