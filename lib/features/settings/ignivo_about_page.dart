import 'package:flutter/material.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_brand_logo.dart';
import '../../widgets/ignivo_sheet.dart';

/// Trang giới thiệu chính thức của ứng dụng IGNIVO Smart Safety (Production)
class IgnivoAboutPage extends StatelessWidget {
  const IgnivoAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? BrandTokens.darkBackground : BrandTokens.background,
      appBar: AppBar(
        title: const Text('Giới thiệu IGNIVO'),
        elevation: 0,
        backgroundColor: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        foregroundColor: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            // Logo thương hiệu chuẩn Stitch
            const Center(
              child: IgnivoBrandLogo(
                markSize: 44,
                wordmarkWidth: 130,
                wordmarkHeight: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Phát hiện sớm. Bảo vệ kịp thời.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint,
                borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
              ),
              child: Text(
                'Phiên bản 1.0.0 (Stitch Release)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Card thông tin công nghệ & an toàn
            Container(
              decoration: BoxDecoration(
                color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
                borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
                border: Border.all(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kiến trúc An toàn Cục bộ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  IgnivoDataRow(
                    label: 'Bộ xử lý trung tâm',
                    value: 'Raspberry Pi 5 Edge Box',
                  ),
                  IgnivoDataRow(
                    label: 'Tăng tốc thị giác AI',
                    value: 'Hailo-8L NPU',
                  ),
                  IgnivoDataRow(
                    label: 'Bảo mật phiên',
                    value: 'RAM-only session',
                  ),
                  IgnivoDataRow(
                    label: 'Vận hành khẩn cấp',
                    value: 'LAN Offline-ready',
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card mô tả giải pháp
            Container(
              decoration: BoxDecoration(
                color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
                borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
                border: Border.all(
                  color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Về IGNIVO Smart Safety',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'IGNIVO là hệ sinh thái cảnh báo sớm cháy nổ thông minh, tích hợp camera thị giác máy tính và còi báo động khẩn cấp. Mọi suy luận nhận diện được thực hiện hoàn toàn tại thiết bị biên (Edge AI), đảm bảo phát hiện kịp thời ngay cả khi mất kết nối Internet.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Footer
            Text(
              'IGNIVO · Smart Safety © 2026',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
