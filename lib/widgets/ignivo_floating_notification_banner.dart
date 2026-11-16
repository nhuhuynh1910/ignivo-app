import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/push_notification_model.dart';
import '../core/theme/brand_tokens.dart';

/// Card thông báo nổi (In-App Floating Banner) hiển thị phía trên đỉnh màn hình
/// Phong cách IGNIVO Design Token: Bo góc 16px, hiệu ứng đổ bóng mờ, viền báo động
class IgnivoFloatingNotificationBanner extends StatefulWidget {
  const IgnivoFloatingNotificationBanner({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  final IgnivoPushNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  /// Phương thức hiển thị nhanh trên Overlay của ứng dụng
  /// Tự động kéo dài thời gian 15 giây cho báo động cháy khẩn cấp để đảm bảo an toàn
  static OverlayEntry? show(
    BuildContext context, {
    required IgnivoPushNotification notification,
    VoidCallback? onTap,
    Duration? duration,
  }) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return null;

    final resolvedDuration = duration ??
        (notification.category == PushNotificationCategory.fireEmergency
            ? const Duration(seconds: 15)
            : const Duration(seconds: 6));

    late OverlayEntry entry;
    Timer? dismissTimer;

    void removeEntry() {
      dismissTimer?.cancel();
      if (entry.mounted) {
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: IgnivoFloatingNotificationBanner(
            notification: notification,
            onTap: () {
              removeEntry();
              onTap?.call();
            },
            onDismiss: removeEntry,
          ),
        ),
      ),
    );

    overlayState.insert(entry);
    dismissTimer = Timer(resolvedDuration, removeEntry);
    return entry;
  }

  @override
  State<IgnivoFloatingNotificationBanner> createState() =>
      _IgnivoFloatingNotificationBannerState();
}

class _IgnivoFloatingNotificationBannerState
    extends State<IgnivoFloatingNotificationBanner>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    if (widget.notification.category == PushNotificationCategory.fireEmergency) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }

    _animController.forward();
    _triggerHaptic();
  }

  void _triggerHaptic() {
    if (widget.notification.category == PushNotificationCategory.fireEmergency) {
      HapticFeedback.heavyImpact();
      _hapticTimer?.cancel();
      _hapticTimer = Timer(const Duration(milliseconds: 160), () {
        HapticFeedback.heavyImpact();
      });
    } else if (widget.notification.isKnownPerson == false) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _pulseController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _animController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFire = widget.notification.category == PushNotificationCategory.fireEmergency;

    final Color accentColor;
    final IconData iconData;
    final String tagLabel;

    if (isFire) {
      accentColor = BrandTokens.stitchCritical;
      iconData = Icons.local_fire_department_rounded;
      if (widget.notification.isSimulation) {
        tagLabel = 'MÔ PHỎNG';
      } else if (widget.notification.triggerType == 'SMOKE') {
        tagLabel = 'CẢNH BÁO KHÓI';
      } else {
        tagLabel = 'KHẨN CẤP';
      }
    } else {
      switch (widget.notification.category) {
        case PushNotificationCategory.faceRecognition:
          final isKnown = widget.notification.isKnownPerson ?? false;
          accentColor = isKnown ? BrandTokens.stitchSafe : BrandTokens.criticalFg;
          iconData = isKnown ? Icons.verified_user_rounded : Icons.person_search_rounded;
          tagLabel = isKnown ? 'NGƯỜI QUEN' : 'CẢNH BÁO';
          break;
        case PushNotificationCategory.systemNotice:
          accentColor = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;
          iconData = Icons.settings_input_composite_rounded;
          tagLabel = 'HỆ THỐNG';
          break;
        case PushNotificationCategory.general:
        case PushNotificationCategory.fireEmergency:
          accentColor = BrandTokens.brandAccent;
          iconData = Icons.notifications_active_rounded;
          tagLabel = 'THÔNG BÁO';
          break;
      }
    }

    final cardBg = isFire
        ? (isDark ? const Color(0xFF2C0D12) : const Color(0xFFFFF1F2))
        : (isDark ? BrandTokens.darkSurface : Colors.white);
    final textColor = isFire
        ? (isDark ? const Color(0xFFFFE4E6) : const Color(0xFF991B1B))
        : (isDark ? BrandTokens.darkTextPrimary : BrandTokens.brandNavy);
    final subtextColor = isFire
        ? (isDark ? const Color(0xFFFECDD3) : const Color(0xFF7F1D1D))
        : (isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: Key(widget.notification.id),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismiss?.call(),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFire ? accentColor : accentColor.withValues(alpha: 0.35),
                width: isFire ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isFire
                      ? accentColor.withValues(alpha: 0.32)
                      : accentColor.withValues(alpha: 0.16),
                  blurRadius: isFire ? 22 : 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box hoặc Thumbnail Image
                    _buildLeading(accentColor, iconData, isFire),
                    const SizedBox(width: 12),

                    // Nội dung thông báo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isFire ? accentColor : accentColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isFire) ...[
                                      const Icon(Icons.warning_amber_rounded, size: 11, color: Colors.white),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      tagLabel,
                                      style: TextStyle(
                                        color: isFire ? Colors.white : accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Vừa xong',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? BrandTokens.darkTextTertiary
                                      : BrandTokens.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Tiêu đề
                          Text(
                            widget.notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: isFire ? 14 : 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Vị trí cụ thể nếu có
                          if (_hasLocation) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.place_rounded,
                                  size: 13,
                                  color: isFire ? accentColor : BrandTokens.brandAccent,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    _resolvedLocationText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isFire ? accentColor : BrandTokens.brandNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                          ],

                          // Nội dung
                          Text(
                            widget.notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Cột Action Buttons bên phải
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                          onPressed: _handleDismiss,
                        ),
                        if (widget.onTap != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isFire) ...[
                                  const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 3),
                                ],
                                const Text(
                                  'Xem',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasLocation {
    final area = widget.notification.area;
    final camera = widget.notification.cameraName;
    return (area != null && area.isNotEmpty) || (camera != null && camera.isNotEmpty);
  }

  String get _resolvedLocationText {
    final area = widget.notification.area;
    final camera = widget.notification.cameraName;
    if (area != null && camera != null && area != camera) {
      return '$area • $camera';
    }
    return area ?? camera ?? '';
  }

  Widget _buildLeading(Color accentColor, IconData fallbackIcon, bool isFire) {
    final imageUrl = widget.notification.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildIconBox(accentColor, fallbackIcon, isFire),
            ),
          ),
          if (isFire)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department, size: 10, color: Colors.white),
              ),
            ),
        ],
      );
    }
    return _buildIconBox(accentColor, fallbackIcon, isFire);
  }

  Widget _buildIconBox(Color accentColor, IconData icon, bool isFire) {
    final baseBox = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isFire ? accentColor.withValues(alpha: 0.18) : accentColor.withValues(alpha: 0.14),
        shape: isFire ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isFire ? null : BorderRadius.circular(12),
        border: isFire ? Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Icon(
        icon,
        color: accentColor,
        size: isFire ? 26 : 22,
      ),
    );

    if (isFire && _pulseAnimation != null) {
      return ScaleTransition(
        scale: _pulseAnimation!,
        child: baseBox,
      );
    }
    return baseBox;
  }
}
