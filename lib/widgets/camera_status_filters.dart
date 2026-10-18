import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

enum CameraFilterCategory {
  all,
  online,
  offline,
  unknown,
}

/// Thanh chip lọc trạng thái camera theo phong cách Stitch
///
/// Hỗ trợ lọc Tất cả, Online, Offline và Chưa rõ với bộ đếm số lượng trực quan.
class CameraStatusFilters extends StatelessWidget {
  const CameraStatusFilters({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.totalCount,
    required this.onlineCount,
    required this.offlineCount,
    this.unknownCount = 0,
  });

  final CameraFilterCategory selected;
  final ValueChanged<CameraFilterCategory> onSelected;
  final int totalCount;
  final int onlineCount;
  final int offlineCount;
  final int unknownCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: BrandTokens.space16),
      child: Row(
        children: [
          _buildFilterChip(
            category: CameraFilterCategory.all,
            label: 'Tất cả',
            count: totalCount,
            isSelected: selected == CameraFilterCategory.all,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            category: CameraFilterCategory.online,
            label: 'Online',
            count: onlineCount,
            isSelected: selected == CameraFilterCategory.online,
            isDark: isDark,
            countColor: BrandTokens.stitchSafe,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            category: CameraFilterCategory.offline,
            label: 'Offline',
            count: offlineCount,
            isSelected: selected == CameraFilterCategory.offline,
            isDark: isDark,
            countColor: BrandTokens.stitchCritical,
          ),
          if (unknownCount > 0) ...[
            const SizedBox(width: 8),
            _buildFilterChip(
              category: CameraFilterCategory.unknown,
              label: 'Chưa rõ',
              count: unknownCount,
              isSelected: selected == CameraFilterCategory.unknown,
              isDark: isDark,
              countColor: BrandTokens.stitchWarning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required CameraFilterCategory category,
    required String label,
    required int count,
    required bool isSelected,
    required bool isDark,
    Color? countColor,
  }) {
    final bgColor = isSelected
        ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
        : (isDark ? BrandTokens.darkSurface : BrandTokens.surface);

    final textColor = isSelected
        ? (isDark ? BrandTokens.darkOnPrimary : Colors.white)
        : (isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary);

    final borderColor = isSelected
        ? Colors.transparent
        : (isDark ? BrandTokens.darkBorder : BrandTokens.border);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(category),
        borderRadius: BorderRadius.circular(9999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark
                              ? BrandTokens.darkPrimary
                              : BrandTokens.brandPrimary)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.25))
                      : (isDark
                          ? BrandTokens.darkSurfaceVariant
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? textColor
                        : (countColor ??
                            (isDark
                                ? BrandTokens.darkTextSecondary
                                : BrandTokens.textSecondary)),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
