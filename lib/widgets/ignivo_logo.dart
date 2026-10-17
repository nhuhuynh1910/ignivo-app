import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

enum IgnivoLogoVariant {
  /// Logo biểu tượng dọc: Ngọn lửa xanh chuyển sắc + khẩu độ camera
  mark,

  /// Logo chữ ngang: Chữ "IGNIVO" cách điệu + chữ O khẩu độ camera
  wordmark,
}

/// Widget hiển thị logo IGNIVO chuẩn hóa theo hai tài sản hình ảnh dự án.
///
/// Hỗ trợ khung nhận diện dạng huy hiệu (Badge Card Container) giúp hiển thị
/// tự nhiên và thẩm mỹ trên cả hai chế độ sáng (Light) và tối (Dark),
/// khắc phục triệt để hạn chế không có kênh alpha (nền trắng đục) của ảnh JPG.
class IgnivoLogo extends StatelessWidget {
  const IgnivoLogo.mark({
    super.key,
    this.size = 72.0,
    this.containerized = true,
    this.semanticLabel = 'Logo IGNIVO',
    this.excludeFromSemantics = false,
  })  : variant = IgnivoLogoVariant.mark,
        width = size,
        height = size;

  const IgnivoLogo.wordmark({
    super.key,
    this.width = 220.0,
    this.height,
    this.containerized = true,
    this.semanticLabel = 'IGNIVO',
    this.excludeFromSemantics = false,
  })  : variant = IgnivoLogoVariant.wordmark,
        size = null;

  const IgnivoLogo.header({
    super.key,
    this.width = 112.0,
    this.containerized = true,
    this.semanticLabel,
    this.excludeFromSemantics = true, // Loại khỏi semantics khi đứng cạnh tên địa điểm đã đọc
  })  : variant = IgnivoLogoVariant.wordmark,
        size = null,
        height = 36.0;

  final IgnivoLogoVariant variant;
  final double? width;
  final double? height;
  final double? size;
  final bool containerized;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = variant == IgnivoLogoVariant.mark
        ? BrandTokens.markAsset
        : BrandTokens.wordmarkAsset;

    Widget imageWidget = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback nhẹ nhàng nếu asset chưa nạp xong
        return Container(
          width: width ?? 48,
          height: height ?? 48,
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: Icon(
            variant == IgnivoLogoVariant.mark
                ? Icons.camera_alt_outlined
                : Icons.shield_outlined,
            color: BrandTokens.brandPrimary,
          ),
        );
      },
    );

    if (excludeFromSemantics) {
      imageWidget = ExcludeSemantics(child: imageWidget);
    } else if (semanticLabel != null) {
      imageWidget = Semantics(
        label: semanticLabel,
        image: true,
        child: imageWidget,
      );
    }

    if (!containerized) {
      return imageWidget;
    }

    // Badge Card Container: Nền trắng sạch, bo góc 12-16px, viền mềm mại
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: variant == IgnivoLogoVariant.wordmark ? 12.0 : 8.0,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.logoBadgeRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          width: 1.0,
        ),
      ),
      child: imageWidget,
    );
  }
}
