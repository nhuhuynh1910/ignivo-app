import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Widget logo nhận diện thương hiệu IGNIVO kết hợp biểu tượng ngọn lửa (mark)
/// và chữ thương hiệu (wordmark) theo chuẩn phong cách Stitch HTML Demo (.ig-brand).
class IgnivoBrandLogo extends StatelessWidget {
  const IgnivoBrandLogo({
    super.key,
    this.markSize = 32.0,
    this.wordmarkWidth = 94.0,
    this.wordmarkHeight = 28.0,
    this.gap = 7.0,
    this.containerized = true,
    this.excludeFromSemantics = false,
  }) : wordmarkOnly = false;

  /// Biến thể gọn dành cho thanh tiêu đề trang (Header)
  const IgnivoBrandLogo.header({
    super.key,
    this.markSize = 28.0,
    this.wordmarkWidth = 84.0,
    this.wordmarkHeight = 26.0,
    this.gap = 6.0,
    this.containerized = true,
    this.excludeFromSemantics = true,
  }) : wordmarkOnly = false;

  /// Biến thể lớn dành cho màn hình khởi động (Splash)
  const IgnivoBrandLogo.splash({
    super.key,
    this.markSize = 100.0,
    this.wordmarkWidth = 190.0,
    this.wordmarkHeight = 56.0,
    this.gap = 18.0,
    this.containerized = true,
    this.excludeFromSemantics = false,
  }) : wordmarkOnly = false;

  /// Biến thể chỉ hiển thị logo chữ IGNIVO (Wordmark Only) dành cho thanh tiêu đề trang chủ
  const IgnivoBrandLogo.wordmarkOnly({
    super.key,
    this.wordmarkWidth = 104.0,
    this.wordmarkHeight = 28.0,
    this.containerized = true,
    this.excludeFromSemantics = false,
  })  : markSize = 0,
        gap = 0,
        wordmarkOnly = true;

  final double markSize;
  final double wordmarkWidth;
  final double wordmarkHeight;
  final double gap;
  final bool containerized;
  final bool excludeFromSemantics;
  final bool wordmarkOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final wordmarkContainer = Container(
      width: wordmarkWidth,
      height: wordmarkHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          width: 1.0,
        ),
      ),
      child: Image.asset(
        BrandTokens.wordmarkAsset,
        fit: BoxFit.contain,
        cacheWidth: (wordmarkWidth * 3).toInt(),
        errorBuilder: (context, error, stackTrace) => const Text(
          'IGNIVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: BrandTokens.brandPrimary,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );

    if (wordmarkOnly) {
      if (excludeFromSemantics) {
        return ExcludeSemantics(child: wordmarkContainer);
      }
      return Semantics(
        label: 'IGNIVO',
        image: true,
        child: wordmarkContainer,
      );
    }

    Widget brandContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Biểu tượng ngọn lửa xanh (Mark)
        Container(
          width: markSize,
          height: markSize * 1.12,
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius * 0.45),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
              width: 1.0,
            ),
          ),
          child: Image.asset(
            BrandTokens.markAsset,
            fit: BoxFit.contain,
            cacheWidth: (markSize * 3).toInt(),
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_fire_department_rounded,
              color: BrandTokens.brandPrimary,
              size: 20,
            ),
          ),
        ),
        SizedBox(width: gap),
        // 2. Chữ thương hiệu IGNIVO (Wordmark)
        wordmarkContainer,
      ],
    );

    if (excludeFromSemantics) {
      return ExcludeSemantics(child: brandContent);
    }

    return Semantics(
      label: 'IGNIVO - Smart Safety',
      image: true,
      child: brandContent,
    );
  }
}
