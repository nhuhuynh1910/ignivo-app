import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
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
    final appearance = AlertAppearance.fromAlert(alert);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: alert.acknowledged
                  ? AppColors.backgroundBlueSoft
                  : appearance.color.withValues(
                alpha: 0.35,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================================
              // ALERT ICON
              // ============================================================

              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: appearance.color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  appearance.icon,
                  color: appearance.color,
                ),
              ),

              const SizedBox(width: 13),

              // ============================================================
              // ALERT CONTENT
              // ============================================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======================================================
                    // TITLE + SEVERITY
                    // ======================================================

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
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

                    const SizedBox(height: 12),

                    // ======================================================
                    // SYSTEM
                    // ======================================================

                    _AlertInfoLine(
                      icon: Icons.home_outlined,
                      label: 'Hệ thống',
                      value: alert.systemName.isNotEmpty
                          ? alert.systemName
                          : 'Không xác định',
                      highlight: true,
                    ),

                    // ======================================================
                    // ZONE
                    // ======================================================

                    if (alert.zoneName.isNotEmpty)
                      _AlertInfoLine(
                        icon: Icons.location_on_outlined,
                        label: 'Khu vực',
                        value: alert.zoneName,
                      ),

                    // ======================================================
                    // CAMERA
                    // ======================================================

                    if (alert.cameraName.isNotEmpty)
                      _AlertInfoLine(
                        icon: Icons.videocam_outlined,
                        label: 'Camera',
                        value: alert.cameraName,
                      ),

                    // ======================================================
                    // MESSAGE
                    // ======================================================

                    if (alert.message.isNotEmpty) ...[
                      const SizedBox(height: 8),

                      Text(
                        alert.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ======================================================
                    // TIME + UNREAD DOT
                    // ======================================================

                    Row(
                      children: [
                        if (alert.createdAt != null)
                          Expanded(
                            child: Text(
                              DateFormat(
                                'dd/MM/yyyy • HH:mm',
                              ).format(
                                alert.createdAt!,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        else
                          const Spacer(),

                        if (!alert.acknowledged)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
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
    );
  }
}

// ============================================================================
// SYSTEM / ZONE / CAMERA INFO LINE
// ============================================================================

class _AlertInfoLine extends StatelessWidget {
  const _AlertInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? AppColors.primary
                : AppColors.textTertiary,
          ),

          const SizedBox(width: 7),

          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: highlight
                  ? AppColors.primaryDark
                  : AppColors.textTertiary,
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: highlight
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEVERITY BADGE
// ============================================================================

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
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// ALERT APPEARANCE
// ============================================================================

class AlertAppearance {
  const AlertAppearance({
    required this.icon,
    required this.color,
    required this.severityLabel,
  });

  final IconData icon;
  final Color color;
  final String severityLabel;

  factory AlertAppearance.fromAlert(
      AlertModel alert,
      ) {
    return AlertAppearance(
      icon: _iconForType(alert.type),
      color: _colorForSeverity(
        alert.severity,
      ),
      severityLabel: _labelForSeverity(
        alert.severity,
      ),
    );
  }

  // ==========================================================================
  // ICON BY ALERT TYPE
  // ==========================================================================

  static IconData _iconForType(
      String type,
      ) {
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
        return Icons.person_outline;

      case 'POWER_LOSS':
      case 'POWER':
        return Icons.power_off_outlined;

      case 'NETWORK':
        return Icons.wifi_off_rounded;

      case 'DEVICE_OFFLINE':
        return Icons.devices_other_outlined;

      default:
        return Icons.notifications_active_outlined;
    }
  }

  // ==========================================================================
  // COLOR BY SEVERITY
  // ==========================================================================

  static Color _colorForSeverity(
      String severity,
      ) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.danger;

      case 'ALERT':
        return AppColors.warning;

      case 'SUSPICIOUS':
        return AppColors.warning;

      case 'NORMAL':
        return AppColors.success;

      default:
        return AppColors.primary;
    }
  }

  // ==========================================================================
  // LABEL BY SEVERITY
  // ==========================================================================

  static String _labelForSeverity(
      String severity,
      ) {
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
        return severity;
    }
  }
}