import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';
import '../features/fireguard/monitor_widgets.dart';
import 'interactive_card.dart';

/// Thẻ sự cố gần đây theo phong cách Stitch
///
/// Trình bày loại sự cố, mức độ nghiêm trọng (severity), khu vực, thời gian
/// và trạng thái xử lý đồng bộ với AlertPresentationMapping.
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
    this.onTap,
  });

  final int id;
  final String title;
  final String area;
  final String timeStr;
  final String? severity;
  final String? status;
  final bool isSimulation;
  final VoidCallback? onTap;

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
              // Icon chỉ báo mức độ
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusStyle.border, width: 1),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: statusStyle.foreground,
                  size: 24,
                ),
              ),
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
