import 'package:flutter/material.dart';

import '../core/theme/brand_tokens.dart';
import 'ignivo_brand_logo.dart';
import 'ignivo_sheet.dart';

/// Shared, layered header for the four primary destinations.
/// Connection freshness is deliberately separate from incident severity.
class IgnivoPageHeader extends StatelessWidget {
  const IgnivoPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.systemName,
    this.action,
    this.showSync = false,
    this.updatedAt,
    this.stale = true,
    this.onTapSystem,
    this.onTapAvatar,
    this.avatarInitials,
    this.compact,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final String systemName;
  final Widget? action;
  final bool showSync;
  final DateTime? updatedAt;
  final bool stale;
  final VoidCallback? onTapSystem;
  final VoidCallback? onTapAvatar;
  final String? avatarInitials;
  final bool? compact;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isCompact = compact ?? (title == 'Trang chủ');
    if (isCompact) {
      return _buildCompactHeader(context);
    }
    return _buildFullHeader(context);
  }

  Widget _buildCompactHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final syncTime = updatedAt?.toLocal();
    final formattedSyncTime = syncTime == null
        ? null
        : '${syncTime.hour.toString().padLeft(2, '0')}:${syncTime.minute.toString().padLeft(2, '0')}';
    final syncTooltip = stale
        ? 'Dữ liệu chưa đồng bộ'
        : formattedSyncTime != null
            ? 'Đã đồng bộ lúc $formattedSyncTime'
            : 'Đã kết nối';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Semantics(
          header: true,
          label: '$title - $systemName',
          child: Row(
            children: [
              if (showBack) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  tooltip: 'Trở về',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const IgnivoBrandLogo.wordmarkOnly(excludeFromSemantics: false),
                const SizedBox(width: 10),
              ],
              // System Selector Pill with integrated Online/Sync dot
              Flexible(
                child: Tooltip(
                  message: '$systemName · $syncTooltip',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (onTapSystem != null) {
                        onTapSystem!();
                      } else {
                        showIgnivoSystemSheet(
                          context: context,
                          systemName: systemName,
                          address: 'Hệ thống FireGuard Edge',
                          isConnected: !stale,
                          cameraCount: 3,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BrandTokens.darkSurfaceVariant
                            : BrandTokens.brandTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? BrandTokens.darkBorder
                              : BrandTokens.brandPrimary.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.router_rounded,
                            size: 16,
                            color: isDark
                                ? BrandTokens.darkPrimary
                                : BrandTokens.brandPrimary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                systemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark
                                      ? BrandTokens.darkTextPrimary
                                      : BrandTokens.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: stale
                                  ? Colors.orange.shade700
                                  : (isDark
                                      ? BrandTokens.stitchDarkOnlineFg
                                      : BrandTokens.stitchOnlineFg),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: isDark
                                ? BrandTokens.darkTextSecondary
                                : BrandTokens.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ?action,
              if (onTapAvatar != null || avatarInitials != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Cài đặt & Tài khoản',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onTapAvatar,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: isDark
                          ? BrandTokens.darkBrandTint
                          : BrandTokens.brandTint,
                      child: avatarInitials != null && avatarInitials != 'MA'
                          ? Text(
                              avatarInitials!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? BrandTokens.darkPrimary
                                    : BrandTokens.brandPrimary,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 17,
                              color: isDark
                                  ? BrandTokens.darkPrimary
                                  : BrandTokens.brandPrimary,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? BrandTokens.darkTextSecondary
        : BrandTokens.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showBack) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    tooltip: 'Trở về',
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                ],
                const IgnivoBrandLogo.wordmarkOnly(excludeFromSemantics: false),
                const Spacer(),
                Tooltip(
                  message: systemName,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (onTapSystem != null) {
                        onTapSystem!();
                      } else {
                        showIgnivoSystemSheet(
                          context: context,
                          systemName: systemName,
                          address: 'Hệ thống FireGuard Edge',
                          isConnected: !stale,
                          cameraCount: 3,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.router_rounded,
                            size: 17,
                            color: isDark
                                ? BrandTokens.darkPrimary
                                : BrandTokens.brandPrimary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                systemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? BrandTokens.darkTextPrimary
                                      : BrandTokens.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: isDark
                                ? BrandTokens.darkTextSecondary
                                : BrandTokens.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Cài đặt & Tài khoản',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onTapAvatar,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark
                          ? BrandTokens.darkBrandTint
                          : BrandTokens.brandTint,
                      child: avatarInitials != null && avatarInitials != 'MA'
                          ? Text(
                              avatarInitials!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? BrandTokens.darkPrimary
                                    : BrandTokens.brandPrimary,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: isDark
                                  ? BrandTokens.darkPrimary
                                  : BrandTokens.brandPrimary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
            if (showSync) ...[
              const SizedBox(height: 14),
              IgnivoSyncStatus(updatedAt: updatedAt, stale: stale),
            ],
          ],
        ),
      ),
    );
  }
}

class IgnivoHeaderAction extends StatelessWidget {
  const IgnivoHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: isDark
            ? BrandTokens.darkBrandTint
            : BrandTokens.brandTint,
        foregroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class IgnivoSyncStatus extends StatelessWidget {
  const IgnivoSyncStatus({
    super.key,
    required this.updatedAt,
    required this.stale,
  });

  final DateTime? updatedAt;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pending = stale || updatedAt == null;
    final style = pending
        ? StatusStyle.warning(isDark: isDark)
        : StatusStyle.normal(isDark: isDark);
    final time = updatedAt?.toLocal();
    final formatted = time == null
        ? null
        : '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}:'
              '${time.second.toString().padLeft(2, '0')}';
    final label = formatted == null
        ? 'Chưa có dữ liệu đồng bộ'
        : pending
        ? 'Dữ liệu chưa đồng bộ · Lần cuối $formatted'
        : 'Đồng bộ lúc $formatted';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            pending ? Icons.sync_problem_outlined : Icons.sync,
            size: 16,
            color: style.foreground,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pending ? style.foreground : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// InheritedWidget that notifies descendants whether a [DesktopTopBar] is already
/// present above the current view, allowing [IgnivoPageBody] to omit the redundant in-page header.
class IgnivoDesktopTopBarScope extends InheritedWidget {
  const IgnivoDesktopTopBarScope({
    super.key,
    required this.hasTopBar,
    required super.child,
  });

  final bool hasTopBar;

  static bool hasTopBarOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IgnivoDesktopTopBarScope>();
    return scope?.hasTopBar ?? false;
  }

  @override
  bool updateShouldNotify(IgnivoDesktopTopBarScope oldWidget) =>
      hasTopBar != oldWidget.hasTopBar;
}

/// Keeps the header outside the scrollable content and below system insets.
class IgnivoPageBody extends StatelessWidget {
  const IgnivoPageBody({
    super.key,
    required this.header,
    required this.child,
    this.hideHeaderOnDesktopTopBar = true,
  });

  final Widget header;
  final Widget child;
  final bool hideHeaderOnDesktopTopBar;

  @override
  Widget build(BuildContext context) {
    final hasDesktopTopBar = hideHeaderOnDesktopTopBar &&
        IgnivoDesktopTopBarScope.hasTopBarOf(context);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: !hasDesktopTopBar,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasDesktopTopBar) header,
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact secondary-page header; native AppBar preserves back navigation.
AppBar ignivoDetailAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
}) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    toolbarHeight:
        (subtitle == null ? 64 : 88) +
        (scaler.scale(18) - 18) * 2.4 +
        (subtitle == null ? 0 : (scaler.scale(12) - 12) * 1.3),
    titleSpacing: 16,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.3,
              color: theme.brightness == Brightness.dark
                  ? BrandTokens.darkTextSecondary
                  : BrandTokens.textSecondary,
            ),
          ),
        ],
      ],
    ),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(height: 1, thickness: 1, color: theme.colorScheme.outline),
    ),
  );
}

class IgnivoAuthHeader extends StatelessWidget {
  const IgnivoAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Biểu tượng Logo thương hiệu IGNIVO ở giữa phóng to
        Center(
          child: Container(
            width: 76,
            height: 82,
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? BrandTokens.darkBorder
                    : BrandTokens.brandAccent.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : BrandTokens.brandPrimary)
                      .withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              BrandTokens.markAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.local_fire_department_rounded,
                color: BrandTokens.brandPrimary,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? BrandTokens.darkTextSecondary
                : BrandTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
