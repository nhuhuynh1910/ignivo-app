import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Thẻ xem camera theo phong cách Stitch với tỷ lệ khung hình 16:9
///
/// Trình bày ảnh snapshot xem trước, trạng thái kết nối, trạng thái AI,
/// metadata khu vực/model và phản hồi chạm xem Live View.
class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({
    super.key,
    required this.name,
    required this.area,
    this.model,
    this.isOnline,
    this.aiEnabled = true,
    this.aiStatusText = 'AI đang giám sát',
    this.aiFps,
    this.snapshotBytes,
    this.isSnapshotLoading = false,
    this.snapshotTime,
    this.isLive = false,
    this.canConfigure = false,
    this.onTap,
    this.onEdit,
  });

  final String name;
  final String area;
  final String? model;
  final bool? isOnline;
  final bool aiEnabled;
  final String aiStatusText;
  final double? aiFps;
  final Uint8List? snapshotBytes;
  final bool isSnapshotLoading;
  final String? snapshotTime;
  final bool isLive;
  final bool canConfigure;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? BrandTokens.darkSurface : BrandTokens.surface;
    final cardBorder = isDark ? BrandTokens.darkBorder : BrandTokens.border;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Khung hình tỷ lệ 16:8.7 (theo CSS demo)
              AspectRatio(
                aspectRatio: 16 / 8.7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImageContent(isDark),
                    _buildGradientOverlay(),
                    _buildTopLeftBadges(),
                    if (aiFps != null && aiFps! > 0) _buildTopRightFpsBadge(),
                    _buildBottomRightTapHint(),
                  ],
                ),
              ),

              // 2. Nội dung thông tin camera bên dưới
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hàng 1: Tên camera + Badge kết nối + Nút sửa
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildConnectionBadge(isOnline),
                        if (canConfigure && onEdit != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                            onPressed: onEdit,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Hàng 2: Trạng thái AI giám sát
                    Row(
                      children: [
                        Icon(
                          aiEnabled
                              ? Icons.smart_toy_rounded
                              : Icons.smart_toy_outlined,
                          size: 16,
                          color: aiEnabled
                              ? BrandTokens.brandPrimary
                              : (isDark
                                  ? BrandTokens.darkTextTertiary
                                  : BrandTokens.textTertiary),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            aiStatusText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: aiEnabled
                                  ? (isDark
                                      ? BrandTokens.darkPrimary
                                      : BrandTokens.brandPrimary)
                                  : (isDark
                                      ? BrandTokens.darkTextSecondary
                                      : BrandTokens.textSecondary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Hàng 3: Metadata (Khu vực • Model • Edge Box)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Khu vực: $area',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? BrandTokens.darkTextSecondary
                                  : BrandTokens.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (model != null && model!.trim().isNotEmpty) ...[
                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                          Flexible(
                            child: Text(
                              model!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                  ? BrandTokens.darkTextSecondary
                                  : BrandTokens.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.router_rounded,
                              size: 13,
                              color: isDark
                                  ? BrandTokens.darkPrimary
                                  : BrandTokens.brandPrimary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Edge Box',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? BrandTokens.darkPrimary
                                    : BrandTokens.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: onTap,
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text(
                          'Xem trực tiếp (Live View)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
    ),
  ),
);
}

  Widget _buildImageContent(bool isDark) {
    if (snapshotBytes != null && snapshotBytes!.isNotEmpty) {
      return Image.memory(
        snapshotBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(isDark, errorText: 'Không đọc được ảnh'),
      );
    }

    if (isSnapshotLoading) {
      return Container(
        color: const Color(0xFF1E293B),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        ),
      );
    }

    return _buildPlaceholder(isDark);
  }

  Widget _buildPlaceholder(bool isDark, {String? errorText}) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline == false
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              color: Colors.white38,
              size: 38,
            ),
            const SizedBox(height: 6),
            Text(
              errorText ??
                  (isOnline == false
                      ? 'Camera ngoại tuyến'
                      : 'Chưa có ảnh xem trước'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.45),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.65),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildTopLeftBadges() {
    return Positioned(
      top: 10,
      left: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BrandTokens.stitchCritical,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera, size: 10, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    snapshotTime != null ? 'Ảnh • $snapshotTime' : 'Ảnh xem trước',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopRightFpsBadge() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: BrandTokens.stitchSafe,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${aiFps!.toStringAsFixed(0)} FPS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomRightTapHint() {
    return Positioned(
      bottom: 8,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 12, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              'Chạm xem trực tiếp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBadge(bool? online) {
    if (online == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          'Chưa rõ',
          style: TextStyle(
            color: Colors.amber.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (online) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: BrandTokens.stitchSafe.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, size: 8, color: BrandTokens.stitchSafe),
            SizedBox(width: 4),
            Text(
              'ONLINE',
              style: TextStyle(
                color: BrandTokens.stitchSafe,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BrandTokens.stitchCritical.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 8, color: BrandTokens.stitchCritical),
          SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: TextStyle(
              color: BrandTokens.stitchCritical,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
