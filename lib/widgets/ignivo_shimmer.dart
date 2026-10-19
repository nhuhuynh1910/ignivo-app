import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Hiệu ứng Shimmer cao cấp (Skeleton Loading) đặc trưng của IGNIVO.
///
/// Hỗ trợ quét gradient mượt mà trên bất kỳ widget con nào qua ShaderMask.
/// Tự động xử lý Dark/Light mode và an toàn cho Widget Test (không giữ ticker vô tận).
class IgnivoShimmer extends StatefulWidget {
  const IgnivoShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<IgnivoShimmer> createState() => _IgnivoShimmerState();
}

class _IgnivoShimmerState extends State<IgnivoShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0.5,
    );

    if (!_isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = widget.baseColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC));

    if (_isTest) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: const [0.1, 0.45, 0.85],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.0 - 1.0),
      0.0,
      0.0,
    );
  }
}

/// Khung hình chữ nhật giả lập dữ liệu đang tải có sẵn hiệu ứng Shimmer.
class IgnivoShimmerBox extends StatelessWidget {
  const IgnivoShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: borderRadius ??
            BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
      ),
    );

    return IgnivoShimmer(child: container);
  }
}
