import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Thẻ có hiệu ứng tương tác mềm mại (Soft Ambient Shadow + Hover Elevation)
///
/// Tự động thích ứng trên di động (đổ bóng mềm) và trên Web/Desktop (nổi thẻ + phát sáng viền khi rê chuột).
class InteractiveCard extends StatefulWidget {
  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.clipBehavior = Clip.antiAlias,
    this.enableHover = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;
  final bool enableHover;

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final radius = widget.borderRadius ??
        BorderRadius.circular(BrandTokens.stitchCardRadius);
    final bg = widget.backgroundColor ??
        (isDark ? BrandTokens.darkSurface : BrandTokens.surface);
    final defaultBorder = widget.borderColor ??
        (isDark
            ? BrandTokens.darkBorder.withValues(alpha: 0.8)
            : BrandTokens.border.withValues(alpha: 0.8));

    final activeBorder = _isHovered && widget.enableHover
        ? (isDark
            ? BrandTokens.darkPrimary.withValues(alpha: 0.6)
            : BrandTokens.brandPrimary.withValues(alpha: 0.4))
        : defaultBorder;

    final shadows = _isHovered && widget.enableHover
        ? BrandTokens.hoverShadow(isDark: isDark)
        : BrandTokens.softShadow(isDark: isDark);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          _isHovered && widget.enableHover ? -2.5 : 0,
          0,
        ),
        margin: widget.margin,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: activeBorder,
            width: _isHovered && widget.enableHover ? 1.2 : 1.0,
          ),
          boxShadow: shadows,
        ),
        clipBehavior: widget.clipBehavior,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
