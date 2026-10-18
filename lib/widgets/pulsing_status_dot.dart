import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Chấm trạng thái có hiệu ứng nhịp đập (Pulsing Radar Wave)
///
/// Tạo cảm giác hệ thống đang trực tiếp hoạt động 24/7 (AI Edge đang quét, Camera Live).
class PulsingStatusDot extends StatefulWidget {
  const PulsingStatusDot({
    super.key,
    this.color = BrandTokens.stitchSafe,
    this.size = 8.0,
    this.pulseSize = 20.0,
    this.isPulsing = true,
  });

  final Color color;
  final double size;
  final double pulseSize;
  final bool isPulsing;

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      value: 1.0,
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    if (widget.isPulsing && !_isTest) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsingStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing && !_isTest) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.pulseSize,
      height: widget.pulseSize,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isPulsing)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: widget.pulseSize,
                      height: widget.pulseSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(
                          alpha: _opacityAnimation.value,
                        ),
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
