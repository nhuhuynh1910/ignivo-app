import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/brand_tokens.dart';
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
  });

  final AlertModel alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appearance = AlertAppearance.fromAlert(alert, isDark: isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: alert.acknowledged
              ? (isDark ? BrandTokens.darkBorder : BrandTokens.border)
              : appearance.color.withValues(alpha: 0.45),
          width: alert.acknowledged ? 1.0 : 1.5,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alert Category / Severity Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: appearance.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    appearance.icon,
                    color: appearance.color,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 14),

                // Alert Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Title & Severity Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              alert.title.isNotEmpty
                                  ? alert.title
                                  : 'Cảnh báo hệ thống',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? BrandTokens.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SeverityBadge(
                            label: appearance.severityLabel,
                            color: appearance.color,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Context Details: System, Zone, Camera
                      _AlertInfoRow(
                        icon: Icons.memory_rounded,
                        label: 'Edge Box',
                        value: alert.systemName.isNotEmpty
                            ? alert.systemName
                            : 'Chưa xác định',
                        isDark: isDark,
                      ),

                      if (alert.zoneName.isNotEmpty)
                        _AlertInfoRow(
                          icon: Icons.place_rounded,
                          label: 'Khu vực',
                          value: alert.zoneName,
                          isDark: isDark,
                        ),

                      if (alert.cameraName.isNotEmpty)
                        _AlertInfoRow(
                          icon: Icons.videocam_rounded,
                          label: 'Camera',
                          value: alert.cameraName,
                          isDark: isDark,
                        ),

                      if (alert.message.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? BrandTokens.darkSurfaceVariant.withValues(alpha: 0.5)
                                : BrandTokens.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            alert.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark
                                  ? BrandTokens.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Footer: Created Time + Acknowledged Indicator
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isDark
                                ? BrandTokens.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              alert.createdAt != null
                                  ? DateFormat('dd/MM/yyyy • HH:mm')
                                      .format(alert.createdAt!)
                                  : 'Vừa xong',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? BrandTokens.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),

                          if (!alert.acknowledged)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Chưa xử lý',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertInfoRow extends StatelessWidget {
  const _AlertInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? BrandTokens.darkTextTertiary
                  : AppColors.textTertiary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? BrandTokens.darkTextPrimary
                    : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class AlertAppearance {
  const AlertAppearance({
    required this.icon,
    required this.color,
    required this.severityLabel,
  });

  final IconData icon;
  final Color color;
  final String severityLabel;

  factory AlertAppearance.fromAlert(AlertModel alert, {bool isDark = false}) {
    return AlertAppearance(
      icon: _iconForType(alert.type),
      color: _colorForSeverity(alert.severity, isDark: isDark),
      severityLabel: _labelForSeverity(alert.severity),
    );
  }

  static IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'FIRE':
        return Icons.local_fire_department_rounded;
      case 'SMOKE':
        return Icons.cloud_outlined;
      case 'GAS':
      case 'LPG':
        return Icons.propane_tank_outlined;
      case 'INTRUSION':
      case 'UNKNOWN_PERSON':
        return Icons.person_search_rounded;
      case 'POWER_LOSS':
      case 'POWER':
        return Icons.power_off_rounded;
      case 'NETWORK':
        return Icons.wifi_off_rounded;
      case 'DEVICE_OFFLINE':
        return Icons.devices_other_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  static Color _colorForSeverity(String severity, {bool isDark = false}) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg;
      case 'ALERT':
      case 'SUSPICIOUS':
        return isDark ? BrandTokens.darkMediumFg : BrandTokens.mediumFg;
      case 'NORMAL':
        return isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg;
      default:
        return isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;
    }
  }

  static String _labelForSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return 'NGUY HIỂM';
      case 'ALERT':
        return 'CẢNH BÁO';
      case 'SUSPICIOUS':
        return 'BẤT THƯỜNG';
      case 'NORMAL':
        return 'BÌNH THƯỜNG';
      default:
        return severity.toUpperCase();
    }
  }
}
