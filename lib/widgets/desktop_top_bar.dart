import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';
import 'pulsing_status_dot.dart';

/// Thanh tiêu đề mở rộng chuyên biệt cho bản Desktop & Web
///
/// Bổ sung Breadcrumb, tình trạng đồng bộ thời gian thực (WebSocket / Hailo NPU)
/// và nút làm mới nhanh, giúp Web hoạt động như một Security Command Center thực thụ.
class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({
    super.key,
    required this.title,
    required this.systemName,
    this.role,
    this.isWsConnected = true,
    this.isStale = false,
    this.onRefresh,
    this.onOpenDiagnostics,
    this.onTapSystem,
    this.actions,
  });

  final String title;
  final String systemName;
  final String? role;
  final bool isWsConnected;
  final bool isStale;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenDiagnostics;
  final VoidCallback? onTapSystem;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? BrandTokens.darkSurface : BrandTokens.surface;
    final border = isDark
        ? BrandTokens.darkBorder.withValues(alpha: 0.6)
        : BrandTokens.border.withValues(alpha: 0.8);

    final statusColor = isWsConnected && !isStale
        ? BrandTokens.stitchSafe
        : (isStale ? Colors.amber : BrandTokens.stitchCritical);

    final statusLabel = isWsConnected && !isStale
        ? 'Trực tuyến'
        : (isStale ? 'Đang đồng bộ...' : 'Mất kết nối');

    final roleLabel = switch (role?.toUpperCase()) {
      'OWNER' => 'Chủ sở hữu',
      'STAFF' => 'Nhân viên trực',
      _ => 'Người dùng',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 850;
        final isVeryCompact = availableWidth < 680;

        return Container(
          height: 62,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Row(
            children: [
              // 1. Breadcrumbs & Title
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 20,
                      color: isDark
                          ? BrandTokens.darkPrimary
                          : BrandTokens.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    if (!isVeryCompact) ...[
                      Text(
                        'IGNIVO Security',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('›',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? BrandTokens.darkTextPrimary
                              : BrandTokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 2. Telemetry Live Pill (WebSocket / Hailo Status)
              if (!isVeryCompact)
                InkWell(
                  onTap: onOpenDiagnostics,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? BrandTokens.darkBrandTint
                              : BrandTokens.brandTint)
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isDark
                                ? BrandTokens.darkBorder
                                : BrandTokens.border)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulsingStatusDot(
                          color: statusColor,
                          size: 7,
                          pulseSize: 15,
                          isPulsing: isWsConnected && !isStale,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCompact
                              ? (isWsConnected && !isStale
                                  ? 'WS Online'
                                  : 'Syncing')
                              : statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? BrandTokens.darkTextPrimary
                                : BrandTokens.textPrimary,
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 12,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NPU Hailo: Sẵn sàng',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? BrandTokens.darkTextSecondary
                                  : BrandTokens.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              if (onRefresh != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Làm mới dữ liệu (F5)',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: () => onRefresh!(),
                ),
              ],

              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 4),
                ...actions!,
              ],

              const SizedBox(width: 8),

              // 4. User Profile & System Chip
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Tooltip(
                  message: onTapSystem != null
                      ? 'Nhấp để đổi hệ thống giám sát'
                      : systemName,
                  child: InkWell(
                    onTap: onTapSystem,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BrandTokens.darkSurfaceVariant
                            : BrandTokens.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: isDark
                                ? BrandTokens.darkPrimary.withValues(alpha: 0.2)
                                : BrandTokens.brandPrimary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: isDark
                                  ? BrandTokens.darkPrimary
                                  : BrandTokens.brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  systemName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? BrandTokens.darkTextPrimary
                                        : BrandTokens.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  roleLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? BrandTokens.darkTextTertiary
                                        : BrandTokens.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (onTapSystem != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: isDark
                                  ? BrandTokens.darkTextTertiary
                                  : BrandTokens.textTertiary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
