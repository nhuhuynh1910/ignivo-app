import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Thành phần Bottom Sheet chuẩn hóa theo phong cách Stitch HTML Demo (.ig-sheet)
class IgnivoSheet extends StatelessWidget {
  const IgnivoSheet({
    super.key,
    required this.title,
    required this.children,
    this.onClose,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(BrandTokens.sheetRadius),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          ),
          left: BorderSide(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          ),
          right: BorderSide(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 30,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle nhỏ phía trên
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: (isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary)
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Hàng tiêu đề + nút đóng X
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                tooltip: 'Đóng',
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  foregroundColor: isDark
                      ? BrandTokens.darkTextSecondary
                      : BrandTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Dòng hiển thị dữ liệu dạng nhãn - giá trị (.ig-data-row)
class IgnivoDataRow extends StatelessWidget {
  const IgnivoDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? BrandTokens.darkTextSecondary
        : BrandTokens.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13.0),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  width: 1.0,
                ),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
              fontSize: 13.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.0,
                      color: valueColor ??
                          (isDark
                              ? BrandTokens.darkTextPrimary
                              : BrandTokens.textPrimary),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung thông tin phụ trợ (.ig-info)
class IgnivoInfoBox extends StatelessWidget {
  const IgnivoInfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;
    final muted = isDark
        ? BrandTokens.darkTextSecondary
        : BrandTokens.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
        borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primary,
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Mở Bottom Sheet Ignivo chuẩn hóa
Future<T?> showIgnivoModalSheet<T>({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  VoidCallback? onClose,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => IgnivoSheet(
      title: title,
      onClose: onClose,
      children: children,
    ),
  );
}

/// Bottom Sheet: Thông tin Edge Box (.system)
Future<void> showIgnivoSystemSheet({
  required BuildContext context,
  required String systemName,
  required String address,
  required bool isConnected,
  required int cameraCount,
  VoidCallback? onDiagnostics,
  VoidCallback? onChangeConnection,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showIgnivoModalSheet(
    context: context,
    title: 'Hệ thống của bạn',
    children: [
      IgnivoInfoBox(
        icon: Icons.router_rounded,
        title: systemName,
        subtitle: 'IGNIVO Edge Box · Hệ thống giám sát cục bộ',
      ),
      IgnivoDataRow(label: 'Địa chỉ', value: address),
      IgnivoDataRow(
        label: 'Kết nối',
        value: isConnected ? 'Đã kết nối' : 'Chưa xác định',
        valueColor: isConnected
            ? (isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg)
            : (isDark ? BrandTokens.darkMediumFg : BrandTokens.mediumFg),
      ),
      IgnivoDataRow(
        label: 'Camera',
        value: '$cameraCount đã cấu hình',
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: isDark
              ? BrandTokens.darkPrimary
              : BrandTokens.brandPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
          ),
        ),
        onPressed: () {
          Navigator.of(context).pop();
          if (onDiagnostics != null) {
            onDiagnostics();
          }
        },
        icon: const Icon(Icons.monitor_heart_outlined, size: 20),
        label: const Text('Chẩn đoán hệ thống'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
          ),
        ),
        onPressed: () {
          Navigator.of(context).pop();
          if (onChangeConnection != null) {
            onChangeConnection();
          }
        },
        icon: const Icon(Icons.swap_horiz_rounded, size: 20),
        label: const Text('Đổi kết nối'),
      ),
    ],
  );
}

/// Bottom Sheet: Chẩn đoán hệ thống (.diagnostics)
Future<void> showIgnivoDiagnosticsSheet({
  required BuildContext context,
  required bool isConnected,
  required bool isDirectAlertConnected,
  required int onlineCameras,
  required int totalCameras,
  required String lastSyncTime,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showIgnivoModalSheet(
    context: context,
    title: 'Chẩn đoán hệ thống',
    children: [
      IgnivoDataRow(
        label: 'Dịch vụ Edge',
        value: isConnected ? 'Hoạt động' : 'Mất kết nối',
        valueColor: isConnected
            ? (isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg)
            : (isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg),
      ),
      IgnivoDataRow(
        label: 'Cảnh báo trực tiếp',
        value: isDirectAlertConnected ? 'Đã kết nối' : 'Đang kết nối lại',
        valueColor: isDirectAlertConnected
            ? (isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg)
            : (isDark ? BrandTokens.darkMediumFg : BrandTokens.mediumFg),
      ),
      IgnivoDataRow(
        label: 'Camera trực tuyến',
        value: '$onlineCameras / $totalCameras',
      ),
      IgnivoDataRow(
        label: 'Dữ liệu gần nhất',
        value: lastSyncTime.isEmpty ? 'Chưa có' : lastSyncTime,
        showDivider: false,
      ),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: isDark
              ? BrandTokens.darkPrimary
              : BrandTokens.brandPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Đóng'),
      ),
    ],
  );
}

/// Bottom Sheet: Liên hệ khẩn cấp (.contacts)
Future<void> showIgnivoContactsSheet({
  required BuildContext context,
  required String primaryContact,
  required String secondaryContact,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final muted = isDark
      ? BrandTokens.darkTextSecondary
      : BrandTokens.textSecondary;

  return showIgnivoModalSheet(
    context: context,
    title: 'Liên hệ khẩn cấp',
    children: [
      IgnivoDataRow(
        label: 'Liên hệ gia đình',
        value: primaryContact.isEmpty ? 'Chưa cấu hình' : primaryContact,
      ),
      IgnivoDataRow(
        label: 'Liên hệ dự phòng',
        value: secondaryContact.isEmpty ? 'Chưa cấu hình' : secondaryContact,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Text(
          'Danh bạ gia đình và đội PCCC cơ sở hỗ trợ xử lý sự cố kịp thời.',
          style: TextStyle(color: muted, fontSize: 12.0),
        ),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: isDark
              ? BrandTokens.darkPrimary
              : BrandTokens.brandPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Đóng'),
      ),
    ],
  );
}

/// Bottom Sheet: Xác nhận thao tác sự cố hoặc hệ thống (.confirm)
Future<bool?> showIgnivoConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool isDanger = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final muted = isDark
      ? BrandTokens.darkTextSecondary
      : BrandTokens.textSecondary;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => IgnivoSheet(
      title: title,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Text(
            message,
            style: TextStyle(color: muted, fontSize: 13.5, height: 1.45),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: isDanger
                ? (isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg)
                : (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Hủy'),
        ),
      ],
    ),
  );
}
