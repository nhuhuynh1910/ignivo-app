import 'package:flutter/material.dart';

/// IGNIVO Brand & Safety Design Tokens
///
/// Thống nhất màu sắc nhận diện thương hiệu công nghệ (Blue/Cyan/Navy)
/// tách bạch hoàn toàn với ngữ nghĩa an toàn/cảnh báo (Red/Amber/Green/Grey).
class BrandTokens {
  BrandTokens._();

  // ==========================================
  // BRAND IDENTITY (LIGHT THEME) — STITCH
  // ==========================================
  static const Color brandPrimary = Color(0xFF005CAF);
  static const Color brandSecondary = Color(0xFF005AC4);
  static const Color brandCyan = Color(0xFF16B9EE);
  static const Color brandNavy = Color(0xFF102449);
  static const Color background = Color(0xFFF5F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF181C24);
  static const Color textSecondary = Color(0xFF586678);
  static const Color textTertiary = Color(0xFF717785);
  static const Color border = Color(0xFFE2E8F0);
  static const Color brandTint = Color(0xFFEAF3FF);

  // Stitch Semantic Tokens
  static const Color stitchSafe = Color(0xFF10B981);
  static const Color stitchWarning = Color(0xFFF59E0B);
  static const Color stitchCritical = Color(0xFFEF4444);

  // Stitch Demo Status Palette (Light)
  static const Color stitchOnlineFg = Color(0xFF087C59);
  static const Color stitchOnlineBg = Color(0xFFE5F7EF);
  static const Color stitchCriticalFg = Color(0xFFB72832);
  static const Color stitchCriticalBg = Color(0xFFFFF0F0);
  static const Color stitchCriticalBorder = Color(0xFFF4BBC0);
  static const Color stitchWarningFg = Color(0xFF925700);
  static const Color stitchWarningBg = Color(0xFFFFF4DC);
  static const Color stitchOfflineFg = Color(0xFF586678);
  static const Color stitchOfflineBg = Color(0xFFF5F8FC);

  // ==========================================
  // BRAND IDENTITY (DARK THEME)
  // ==========================================
  static const Color darkBackground = Color(0xFF091426);
  static const Color darkSurface = Color(0xFF101E35);
  static const Color darkSurfaceVariant = Color(0xFF1B2B48);
  static const Color darkTextPrimary = Color(0xFFEDF4FF);
  static const Color darkTextSecondary = Color(0xFFB4C3D8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkPrimary = Color(0xFF63CBFF);
  static const Color stitchDarkPrimary = Color(0xFF83C9FF);
  static const Color darkOnPrimary = Color(0xFF06152F);
  static const Color darkBorder = Color(0xFF283B57);
  static const Color darkBrandTint = Color(0xFF183150);

  // Stitch Demo Status Palette (Dark)
  static const Color stitchDarkOnlineFg = Color(0xFF6EE7B7);
  static const Color stitchDarkOnlineBg = Color(0xFF123B32);
  static const Color stitchDarkCriticalFg = Color(0xFFFFB4B8);
  static const Color stitchDarkCriticalBg = Color(0xFF40202C);
  static const Color stitchDarkCriticalBorder = Color(0xFF8A4556);
  static const Color stitchDarkWarningFg = Color(0xFFFFD37A);
  static const Color stitchDarkWarningBg = Color(0xFF3C301F);
  static const Color stitchDarkOfflineFg = Color(0xFFB4C3D8);
  static const Color stitchDarkOfflineBg = Color(0xFF091426);

  // ==========================================
  // STATUS & ALERT SEMANTIC COLORS (LIGHT MODE)
  // ==========================================
  static const Color criticalFg = Color(0xFFB91C1C);
  static const Color criticalBg = Color(0xFFFEF2F2);
  static const Color criticalBorder = Color(0xFFFCA5A5);

  static const Color highFg = Color(0xFFDC2626);
  static const Color highBg = Color(0xFFFFF1F2);
  static const Color highBorder = Color(0xFFFECDD3);

  static const Color mediumFg = Color(0xFFD97706);
  static const Color mediumBg = Color(0xFFFFFBEB);
  static const Color mediumBorder = Color(0xFFFDE68A);

  static const Color lowFg = Color(0xFF4B5563);
  static const Color lowBg = Color(0xFFF3F4F6);
  static const Color lowBorder = Color(0xFFE5E7EB);

  static const Color normalFg = Color(0xFF059669);
  static const Color normalBg = Color(0xFFECFDF5);
  static const Color normalBorder = Color(0xFFA7F3D0);

  static const Color staleFg = Color(0xFF6B7280);
  static const Color staleBg = Color(0xFFF9FAFB);
  static const Color staleBorder = Color(0xFFE5E7EB);

  // ==========================================
  // STATUS & ALERT SEMANTIC COLORS (DARK MODE)
  // ==========================================
  static const Color darkCriticalFg = Color(0xFFEF4444);
  static const Color darkCriticalBg = Color(0xFF450A0A);
  static const Color darkCriticalBorder = Color(0xFF7F1D1D);

  static const Color darkHighFg = Color(0xFFF87171);
  static const Color darkHighBg = Color(0xFF4C0519);
  static const Color darkHighBorder = Color(0xFF9F1239);

  static const Color darkMediumFg = Color(0xFFFBBF24);
  static const Color darkMediumBg = Color(0xFF451A03);
  static const Color darkMediumBorder = Color(0xFF78350F);

  static const Color darkLowFg = Color(0xFF9CA3AF);
  static const Color darkLowBg = Color(0xFF1F2937);
  static const Color darkLowBorder = Color(0xFF374151);

  static const Color darkNormalFg = Color(0xFF10B981);
  static const Color darkNormalBg = Color(0xFF064E3B);
  static const Color darkNormalBorder = Color(0xFF047857);

  static const Color darkStaleFg = Color(0xFF94A3B8);
  static const Color darkStaleBg = Color(0xFF0F172A);
  static const Color darkStaleBorder = Color(0xFF334155);

  // ==========================================
  // RADIUS TOKENS
  // ==========================================
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;
  static const double badgeRadius = 20.0;
  static const double logoBadgeRadius = 14.0;
  static const double sheetRadius = 24.0;

  // Stitch Spec Radii
  static const double stitchCardRadius = 20.0;
  static const double stitchSmallCardRadius = 16.0;
  static const double stitchInputRadius = 14.0;

  // ==========================================
  // SPACING TOKENS
  // ==========================================
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // ==========================================
  // ASSET PATHS
  // ==========================================
  static const String markAsset = 'assets/images/ignivo_mark.jpg';
  static const String wordmarkAsset = 'assets/images/ignivo_wordmark.jpg';
  static const String legacyLogoAsset = 'assets/images/ignivo_logo.png';
}

/// Bộ màu trạng thái an toàn có hỗ trợ phân giải sáng/tối
class StatusStyle {
  const StatusStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;

  static StatusStyle forSeverity(String? severity, {required bool isDark}) {
    final s = severity?.toLowerCase().trim();
    if (isDark) {
      return switch (s) {
        'critical' => const StatusStyle(
            foreground: BrandTokens.darkCriticalFg,
            background: BrandTokens.darkCriticalBg,
            border: BrandTokens.darkCriticalBorder,
          ),
        'high' => const StatusStyle(
            foreground: BrandTokens.darkHighFg,
            background: BrandTokens.darkHighBg,
            border: BrandTokens.darkHighBorder,
          ),
        'medium' => const StatusStyle(
            foreground: BrandTokens.darkMediumFg,
            background: BrandTokens.darkMediumBg,
            border: BrandTokens.darkMediumBorder,
          ),
        'low' || 'none' => const StatusStyle(
            foreground: BrandTokens.darkLowFg,
            background: BrandTokens.darkLowBg,
            border: BrandTokens.darkLowBorder,
          ),
        _ => const StatusStyle(
            foreground: BrandTokens.darkStaleFg,
            background: BrandTokens.darkStaleBg,
            border: BrandTokens.darkStaleBorder,
          ),
      };
    } else {
      return switch (s) {
        'critical' => const StatusStyle(
            foreground: BrandTokens.criticalFg,
            background: BrandTokens.criticalBg,
            border: BrandTokens.criticalBorder,
          ),
        'high' => const StatusStyle(
            foreground: BrandTokens.highFg,
            background: BrandTokens.highBg,
            border: BrandTokens.highBorder,
          ),
        'medium' => const StatusStyle(
            foreground: BrandTokens.mediumFg,
            background: BrandTokens.mediumBg,
            border: BrandTokens.mediumBorder,
          ),
        'low' || 'none' => const StatusStyle(
            foreground: BrandTokens.lowFg,
            background: BrandTokens.lowBg,
            border: BrandTokens.lowBorder,
          ),
        _ => const StatusStyle(
            foreground: BrandTokens.staleFg,
            background: BrandTokens.staleBg,
            border: BrandTokens.staleBorder,
          ),
      };
    }
  }

  static StatusStyle normal({required bool isDark}) {
    return isDark
        ? const StatusStyle(
            foreground: BrandTokens.darkNormalFg,
            background: BrandTokens.darkNormalBg,
            border: BrandTokens.darkNormalBorder,
          )
        : const StatusStyle(
            foreground: BrandTokens.normalFg,
            background: BrandTokens.normalBg,
            border: BrandTokens.normalBorder,
          );
  }

  static StatusStyle warning({required bool isDark}) {
    return isDark
        ? const StatusStyle(
            foreground: BrandTokens.darkMediumFg,
            background: BrandTokens.darkMediumBg,
            border: BrandTokens.darkMediumBorder,
          )
        : const StatusStyle(
            foreground: BrandTokens.mediumFg,
            background: BrandTokens.mediumBg,
            border: BrandTokens.mediumBorder,
          );
  }

  static StatusStyle stale({required bool isDark}) {
    return isDark
        ? const StatusStyle(
            foreground: BrandTokens.darkStaleFg,
            background: BrandTokens.darkStaleBg,
            border: BrandTokens.darkStaleBorder,
          )
        : const StatusStyle(
            foreground: BrandTokens.staleFg,
            background: BrandTokens.staleBg,
            border: BrandTokens.staleBorder,
          );
  }
}
