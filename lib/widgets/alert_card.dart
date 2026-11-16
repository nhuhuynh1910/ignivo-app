import 'dart:convert';
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
              // EVIDENCE SNAPSHOT / THUMBNAIL
              // ============================================================

              _AlertEvidenceThumbnail(
                snapshotUrl: alert.snapshotUrl,
                appearance: appearance,
              ),

              const SizedBox(width: 14),

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
// ALERT EVIDENCE THUMBNAIL
// ============================================================================

class _AlertEvidenceThumbnail extends StatelessWidget {
  const _AlertEvidenceThumbnail({
    required this.snapshotUrl,
    required this.appearance,
  });

  final String snapshotUrl;
  final AlertAppearance appearance;

  static const double _size = 54.0;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = snapshotUrl.trim();

    if (cleanUrl.isEmpty) {
      return _buildFallback();
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Evidence Image
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: _size,
              height: _size,
              color: appearance.color.withValues(alpha: 0.08),
              child: _buildImage(cleanUrl),
            ),
          ),

          // Border outline
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: appearance.color.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // Category type & severity indicator badge
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: appearance.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
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
                  appearance.icon,
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

  Widget _buildImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  appearance.color.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }

    return Image.network(
      url,
      width: _size,
      height: _size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                appearance.color.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: appearance.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: appearance.color.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          appearance.icon,
          color: appearance.color,
          size: 24,
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