import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';
import '../features/fireguard/monitor_widgets.dart';
import 'ignivo_shimmer.dart';
import 'interactive_card.dart';

/// Thẻ sự cố gần đây theo phong cách Stitch
///
/// Trình bày ảnh snapshot bằng chứng (nếu có), loại sự cố, mức độ nghiêm trọng (severity),
/// khu vực, thời gian và trạng thái xử lý đồng bộ với AlertPresentationMapping.
class RecentIncidentTile extends StatelessWidget {
  const RecentIncidentTile({
    super.key,
    required this.id,
    required this.title,
    required this.area,
    required this.timeStr,
    this.severity,
    this.status,
    this.isSimulation = false,
    this.imageBytes,
    this.isImageLoading = false,
    this.triggerType,
    this.onTap,
  });

  final int id;
  final String title;
  final String area;
  final String timeStr;
  final String? severity;
  final String? status;
  final bool isSimulation;
  final Uint8List? imageBytes;
  final bool isImageLoading;
  final String? triggerType;
  final VoidCallback? onTap;

  static IconData getTriggerIcon(String? trigger) {
    final t = (trigger ?? '').toLowerCase();
    if (t.contains('fire') || t.contains('flame') || t.contains('cháy') || t.contains('lửa')) {
      return Icons.local_fire_department_rounded;
    }
    if (t.contains('smoke') || t.contains('khói')) {
      return Icons.cloud_outlined;
    }
    if (t.contains('camera') || t.contains('vision') || t.contains('motion') || t.contains('ai')) {
      return Icons.videocam_outlined;
    }
    if (t.contains('heat') || t.contains('temp') || t.contains('nhiệt')) {
      return Icons.thermostat_rounded;
    }
    if (t.contains('gas') || t.contains('khí')) {
      return Icons.air_rounded;
    }
    return Icons.local_fire_department_rounded;
  }

  Widget _buildLeadingThumbnail(
    BuildContext context,
    StatusStyle statusStyle,
    bool isDark,
  ) {
    final triggerIcon = getTriggerIcon(triggerType);

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusStyle.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusStyle.border, width: 1),
                  ),
                  child: Icon(
                    triggerIcon,
                    color: statusStyle.foreground,
                    size: 24,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusStyle.border.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: statusStyle.foreground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    triggerIcon,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isImageLoading) {
      return IgnivoShimmerBox(
        width: 48,
        height: 48,
        borderRadius: BorderRadius.circular(12),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: statusStyle.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusStyle.border, width: 1),
      ),
      child: Icon(
        triggerIcon,
        color: statusStyle.foreground,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statusStyle = AlertPresentationMapping.statusStyle(
      severity: severity,
      isDark: isDark,
    );

    final statusLabel = AlertPresentationMapping.statusLabel(status);

    return InteractiveCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
      padding: const EdgeInsets.all(BrandTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail ảnh bằng chứng / Shimmer / Icon chỉ báo
          _buildLeadingThumbnail(context, statusStyle, isDark),
          const SizedBox(width: 12),

              // Thông tin sự cố
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSimulation) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Mô phỏng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (!title.contains('#$id')) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: isDark ? 0.6 : 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$id',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? BrandTokens.darkTextSecondary
                                    : BrandTokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            area,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? BrandTokens.darkTextSecondary
                                  : BrandTokens.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Flexible(
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? BrandTokens.darkTextTertiary
                                  : BrandTokens.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Badge trạng thái
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: statusStyle.border, width: 0.8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusStyle.foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        );
  }
}
