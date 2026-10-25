import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';
import '../features/fireguard/monitor_widgets.dart';
import 'ignivo_shimmer.dart';
import 'interactive_card.dart';

/// Thẻ sự cố gần đây: biểu tượng sự cố, mức độ, khu vực, thời gian
/// và trạng thái xử lý (mức độ được phân biệt với trạng thái).
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
    if (t.contains('fire') || t.contains('flame') ||
        t.contains('cháy') || t.contains('lửa')) {
      return Icons.local_fire_department_rounded;
    }
    if (t.contains('smoke') || t.contains('khói')) {
      return Icons.cloud_outlined;
    }
    if (t.contains('camera') || t.contains('vision') ||
        t.contains('motion') || t.contains('ai')) {
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

  Widget _buildLeadingThumbnail(bool isDark) {
    final triggerIcon = getTriggerIcon(triggerType);
    final iconColor = isDark
        ? const Color(0xFFFF6B6B)
        : BrandTokens.highFg;
    final iconBackground = isDark
        ? BrandTokens.darkHighBg
        : BrandTokens.highBg;
    final iconBorder = isDark
        ? BrandTokens.darkHighBorder
        : BrandTokens.highBorder;

    Widget fallback() => Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: iconBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconBorder, width: 1),
      ),
      child: Icon(triggerIcon, color: iconColor, size: 24),
    );

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.memory(
                imageBytes!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
            ),
            IgnorePointer(
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: iconBorder, width: 1),
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? BrandTokens.darkSurface : Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Icon(triggerIcon, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (isImageLoading) {
      return IgnivoShimmerBox(
        width: 50,
        height: 50,
        borderRadius: BorderRadius.circular(15),
      );
    }

    return fallback();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusKey = status?.trim().toLowerCase() ?? '';
    final severityKey = severity?.trim().toLowerCase() ?? '';

    // Màu của badge theo trạng thái xử lý, KHÔNG theo severity.
    final StatusStyle statusStyle;
    final IconData statusIcon;
    if (statusKey == 'resolved') {
      statusStyle = StatusStyle.normal(isDark: isDark);
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (statusKey == 'false_alarm') {
      statusStyle = StatusStyle.stale(isDark: isDark);
      statusIcon = Icons.remove_circle_outline_rounded;
    } else if (statusKey == 'acknowledged') {
      statusStyle = StatusStyle.warning(isDark: isDark);
      statusIcon = Icons.pending_actions_rounded;
    } else if (['analyzing', 'notifying', 'notified', 'ai_dismissed']
        .contains(statusKey)) {
      statusStyle = StatusStyle(
        foreground: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
        background: isDark ? BrandTokens.darkCriticalBg : BrandTokens.criticalBg,
        border: isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder,
      );
      statusIcon = Icons.error_outline_rounded;
    } else {
      statusStyle = AlertPresentationMapping.statusStyle(
        severity: severity,
        isDark: isDark,
      );
      statusIcon = Icons.info_outline_rounded;
    }

    final statusLabel = AlertPresentationMapping.statusLabel(status);
    final severityStyle = StatusStyle.forSeverity(severity, isDark: isDark);
    final String? severityLabel = switch (severityKey) {
      'critical' => 'Rất nghiêm trọng',
      'high' => 'Mức độ cao',
      'medium' => 'Mức độ vừa',
      'low' => 'Mức độ thấp',
      _ => null,
    };

    final secondaryColor = isDark
        ? BrandTokens.darkTextSecondary
        : BrandTokens.textSecondary;

    return InteractiveCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeadingThumbnail(isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? BrandTokens.darkTextPrimary
                              : BrandTokens.brandNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 19,
                        color: isDark
                            ? BrandTokens.darkTextTertiary
                            : BrandTokens.textTertiary),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: secondaryColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: secondaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: secondaryColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        timeStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusStyle.background,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusStyle.border, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusStyle.foreground, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusStyle.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (severityLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: severityStyle.background,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          severityLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: severityStyle.foreground,
                          ),
                        ),
                      ),
                    if (isSimulation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark
                              ? BrandTokens.darkPrimary
                              : BrandTokens.brandAccent)
                              .withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'Mô phỏng',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? BrandTokens.darkPrimary
                                : BrandTokens.brandPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
