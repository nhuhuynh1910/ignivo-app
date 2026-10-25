import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Control panel cho camera PTZ (Pan-Tilt-Zoom)
/// Hỗ trợ điều hướng 4 chiều, Nút Home/Reset và Nút Zoom In (+), Zoom Out (-)
class PtzControl extends StatelessWidget {
  const PtzControl({
    super.key,
    required this.onDirectionPressed,
    this.onZoomIn,
    this.onZoomOut,
    this.enabled = true,
  });

  final ValueChanged<String> onDirectionPressed;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final bool enabled;

  void _handleZoomIn() {
    if (!enabled) return;
    if (onZoomIn != null) {
      onZoomIn!();
    } else {
      onDirectionPressed('zoom-in');
    }
  }

  void _handleZoomOut() {
    if (!enabled) return;
    if (onZoomOut != null) {
      onZoomOut!();
    } else {
      onDirectionPressed('zoom-out');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;
    final activeBg = isDark ? BrandTokens.darkSurfaceVariant : BrandTokens.brandTint;
    final disabledOpacity = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: disabledOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row chứa D-Pad điều hướng bên trái và Nút Zoom bên phải
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;

              if (isNarrow) {
                return Column(
                  children: [
                    _buildDPad(context, primaryColor, activeBg),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildZoomControls(context, primaryColor, activeBg),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Direction D-Pad
                  _buildDPad(context, primaryColor, activeBg),

                  // Divider
                  Container(
                    height: 120,
                    width: 1,
                    color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  ),

                  // Zoom Controls (Zoom In / Zoom Out)
                  _buildZoomControls(context, primaryColor, activeBg),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDPad(BuildContext context, Color primaryColor, Color activeBg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up
        _PtzButton(
          icon: Icons.keyboard_arrow_up_rounded,
          tooltip: 'Xoay lên',
          enabled: enabled,
          onPressed: () => onDirectionPressed('UP'),
          primaryColor: primaryColor,
          backgroundColor: activeBg,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left
            _PtzButton(
              icon: Icons.keyboard_arrow_left_rounded,
              tooltip: 'Xoay trái',
              enabled: enabled,
              onPressed: () => onDirectionPressed('LEFT'),
              primaryColor: primaryColor,
              backgroundColor: activeBg,
            ),
            const SizedBox(width: 6),
            // Center / Home
            InkWell(
              onTap: enabled ? () => onDirectionPressed('CENTER') : null,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: BrandTokens.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: BrandTokens.glowShadow(primaryColor, opacity: 0.2),
                ),
                child: const Icon(
                  Icons.filter_center_focus_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Right
            _PtzButton(
              icon: Icons.keyboard_arrow_right_rounded,
              tooltip: 'Xoay phải',
              enabled: enabled,
              onPressed: () => onDirectionPressed('RIGHT'),
              primaryColor: primaryColor,
              backgroundColor: activeBg,
            ),
          ],
        ),
        // Down
        _PtzButton(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: 'Xoay xuống',
          enabled: enabled,
          onPressed: () => onDirectionPressed('DOWN'),
          primaryColor: primaryColor,
          backgroundColor: activeBg,
        ),
      ],
    );
  }

  Widget _buildZoomControls(BuildContext context, Color primaryColor, Color activeBg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'THU PHÓNG (ZOOM)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom In
            _ZoomCardButton(
              icon: Icons.zoom_in_rounded,
              label: 'Phóng to',
              tag: '+',
              enabled: enabled,
              onPressed: _handleZoomIn,
              primaryColor: primaryColor,
            ),
            const SizedBox(width: 12),
            // Zoom Out
            _ZoomCardButton(
              icon: Icons.zoom_out_rounded,
              label: 'Thu nhỏ',
              tag: '-',
              enabled: enabled,
              onPressed: _handleZoomOut,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _PtzButton extends StatelessWidget {
  const _PtzButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    required this.primaryColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: 28),
        color: primaryColor,
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _ZoomCardButton extends StatelessWidget {
  const _ZoomCardButton({
    required this.icon,
    required this.label,
    required this.tag,
    required this.enabled,
    required this.onPressed,
    required this.primaryColor,
  });

  final IconData icon;
  final String label;
  final String tag;
  final bool enabled;
  final VoidCallback onPressed;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? BrandTokens.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            ),
            boxShadow: BrandTokens.softShadow(isDark: isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy,
                ),
              ),
              Text(
                'Zoom $tag',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
