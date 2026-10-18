import 'package:flutter/material.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_logo.dart';

/// Màn hình Splash / Khởi tạo thương hiệu IGNIVO theo draft Stitch (Bản 3)
///
/// Bố cục: Nền xanh nhạt -> Huy hiệu Logo Mark trắng bo góc -> Wordmark -> Slogan
/// "Phát hiện sớm. / Bảo vệ kịp thời." -> Thanh tiến trình khởi tạo và thông tin phiên bản.
class IgnivoStartupView extends StatelessWidget {
  const IgnivoStartupView({
    super.key,
    this.statusMessage = 'Đang kết nối hệ sinh thái IGNIVO...',
    this.errorMessage,
    this.onRetry,
  });

  final String statusMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? BrandTokens.darkBackground : BrandTokens.background;
    final textSecondary = isDark
        ? BrandTokens.darkTextSecondary
        : BrandTokens.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrandTokens.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Khoảng đệm trên cùng
              const SizedBox(height: BrandTokens.space24),

              // 2. Cụm nhận diện thương hiệu trung tâm
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Mark trong Badge Container
                  const IgnivoLogo.mark(size: 80),
                  const SizedBox(height: BrandTokens.space16),

                  // Wordmark IGNIVO
                  const IgnivoLogo.wordmark(width: 170),
                  const SizedBox(height: BrandTokens.space16),

                  // Slogan 2 dòng không chồng chữ
                  Text(
                    'Phát hiện sớm.\nBảo vệ kịp thời.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),

              // 3. Tiến trình khởi tạo & phiên bản chân trang
              Padding(
                padding: const EdgeInsets.only(bottom: BrandTokens.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null) ...[
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? BrandTokens.darkCriticalFg
                              : BrandTokens.criticalFg,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (onRetry != null)
                        ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Thử lại'),
                        ),
                    ] else ...[
                      // Thanh tiến trình mỏng 3.5px bo tròn
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: SizedBox(
                          width: 240,
                          height: 3.5,
                          child: LinearProgressIndicator(
                            backgroundColor: isDark
                                ? BrandTokens.darkBorder
                                : const Color(0xFFDFE2EE),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? BrandTokens.darkPrimary
                                  : BrandTokens.brandPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sync,
                            size: 13,
                            color: isDark
                                ? BrandTokens.darkPrimary
                                : BrandTokens.brandPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Phiên bản 1.0.0 (Stitch Release) • Edge AI Architecture',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? BrandTokens.darkTextTertiary
                            : BrandTokens.textTertiary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
