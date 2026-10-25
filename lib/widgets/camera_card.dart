import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/brand_tokens.dart';
import '../models/camera_model.dart';

class CameraCard extends StatefulWidget {
  const CameraCard({
    super.key,
    required this.camera,
    this.onTap,
  });

  final CameraModel camera;
  final VoidCallback? onTap;

  @override
  State<CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<CameraCard> {
  Timer? _refreshTimer;
  int _refreshKey = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _startRefreshing();
  }

  void _startRefreshing() {
    _refreshTimer?.cancel();

    if (!widget.camera.online ||
        widget.camera.snapshotUrl == null ||
        widget.camera.snapshotUrl!.isEmpty) {
      return;
    }

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          _refreshKey = DateTime.now().millisecondsSinceEpoch;
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant CameraCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.camera.snapshotUrl != widget.camera.snapshotUrl ||
        oldWidget.camera.online != widget.camera.online) {
      _refreshKey = DateTime.now().millisecondsSinceEpoch;
      _startRefreshing();
    }
  }

  String get _snapshotUrl {
    final url = widget.camera.snapshotUrl!;
    final uri = Uri.tryParse(url);

    if (uri == null) return url;

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        '_t': _refreshKey.toString(),
      },
    ).toString();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasSnapshot =
        camera.snapshotUrl != null && camera.snapshotUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live snapshot preview
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(BrandTokens.cardRadius),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(BrandTokens.cardRadius),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasSnapshot && camera.online)
                        Image.network(
                          _snapshotUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              const _CardPlaceholder(),
                        )
                      else
                        const _CardPlaceholder(),

                      // Online / Offline Status Badge
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: camera.online
                                ? BrandTokens.stitchSafe.withValues(alpha: 0.9)
                                : BrandTokens.criticalFg.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                camera.online ? 'Online' : 'Offline',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (camera.online && hasSnapshot)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.60),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Tự động cập nhật',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Camera information
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            camera.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? BrandTokens.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Model: ${camera.model}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? BrandTokens.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (camera.aiMonitored)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? BrandTokens.darkPrimary
                                  : AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              size: 14,
                              color: isDark
                                  ? BrandTokens.darkPrimary
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? BrandTokens.darkPrimary
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
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

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(
          Icons.videocam_off_rounded,
          color: Colors.white38,
          size: 42,
        ),
      ),
    );
  }
}
