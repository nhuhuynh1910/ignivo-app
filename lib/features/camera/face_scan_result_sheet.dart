import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/fireeye_api_service.dart';
import '../../core/theme/brand_tokens.dart';

class FaceScanResultSheet extends StatelessWidget {
  const FaceScanResultSheet({
    super.key,
    required this.result,
    required this.eye,
    this.onOpenPeoplePage,
    this.onRescan,
  });

  final Map<String, dynamic> result;
  final FireeyeApiService eye;
  final VoidCallback? onOpenPeoplePage;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final facesDetected = result['faces_detected'] as int? ?? 0;
    final rawResults = (result['results'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final snapshotPath = result['snapshot']?.toString();

    final bgColor = isDark ? BrandTokens.darkSurface : BrandTokens.surface;
    final textPrimary =
        isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary;
    final textSecondary =
        isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(
            color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
            width: 1.5,
          ),
        ),
        boxShadow: BrandTokens.hoverShadow(isDark: isDark),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? BrandTokens.darkPrimary
                              : BrandTokens.brandPrimary)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 22,
                      color: isDark
                          ? BrandTokens.darkPrimary
                          : BrandTokens.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kết quả quét gương mặt AI',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          facesDetected == 0
                              ? 'Không phát hiện mục tiêu'
                              : 'Phát hiện $facesDetected khuôn mặt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Snapshot Image Preview (nếu có từ Dahua)
              if (snapshotPath != null && snapshotPath.isNotEmpty) ...[
                FutureBuilder<Uint8List>(
                  future: eye.getImage(snapshotPath),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        height: 170,
                        decoration: BoxDecoration(
                          color: isDark
                              ? BrandTokens.darkSurfaceVariant
                              : Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(BrandTokens.cardRadius),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(BrandTokens.cardRadius),
                            child: Image.memory(
                              snapshot.data!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_camera_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Khung hình Dahua AI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 4. Details / Face Matching Results
              if (facesDetected == 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2010)
                        : BrandTokens.stitchWarningBg,
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF7A5210)
                          : BrandTokens.stitchWarning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        color: BrandTokens.stitchWarning,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Không tìm thấy khuôn mặt',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.amber.shade200
                                    : BrandTokens.stitchWarningFg,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Không phát hiện khuôn mặt rõ nét trong khung hình lúc này. Hãy hướng camera về phía đối tượng hoặc điều chỉnh khoảng cách/ánh sáng.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark
                                    ? Colors.amber.shade100.withValues(alpha: 0.8)
                                    : BrandTokens.stitchWarningFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rawResults.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final face = rawResults[index];
                    final isMatched = face['matched'] == true;
                    final name = face['name']?.toString() ??
                        (isMatched ? 'Người quen' : 'Người lạ');
                    final role = face['role']?.toString();
                    final groupTag = face['group_tag']?.toString();
                    final confidence =
                        (face['confidence'] as num?)?.toDouble() ?? 0.0;
                    final confidencePercent =
                        (confidence * 100).toStringAsFixed(1);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMatched
                            ? (isDark
                                ? const Color(0xFF0F2B1D)
                                : BrandTokens.stitchOnlineBg)
                            : (isDark
                                ? const Color(0xFF331A1A)
                                : BrandTokens.stitchCriticalBg),
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                        border: Border.all(
                          color: isMatched
                              ? (isDark
                                  ? const Color(0xFF1F6B43)
                                  : BrandTokens.stitchSafe.withValues(alpha: 0.4))
                              : (isDark
                                  ? const Color(0xFF7A2424)
                                  : BrandTokens.stitchCriticalBorder),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isMatched
                                    ? Icons.verified_user_rounded
                                    : Icons.warning_amber_rounded,
                                color: isMatched
                                    ? BrandTokens.stitchSafe
                                    : BrandTokens.stitchCritical,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isMatched
                                        ? (isDark
                                            ? Colors.green.shade200
                                            : BrandTokens.stitchOnlineFg)
                                        : (isDark
                                            ? Colors.red.shade200
                                            : BrandTokens.stitchCriticalFg),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (isMatched
                                          ? BrandTokens.stitchSafe
                                          : BrandTokens.stitchCritical)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isMatched ? 'Người quen' : 'Người lạ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isMatched
                                        ? BrandTokens.stitchSafe
                                        : BrandTokens.stitchCritical,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (isMatched && (role != null || groupTag != null))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 6,
                                children: [
                                  if (role != null && role.isNotEmpty)
                                    _buildTag(
                                      role,
                                      isDark
                                          ? BrandTokens.darkPrimary
                                          : BrandTokens.brandPrimary,
                                      isDark,
                                    ),
                                  if (groupTag != null && groupTag.isNotEmpty)
                                    _buildTag(
                                      groupTag == 'FAMILY'
                                          ? 'Gia đình'
                                          : groupTag,
                                      Colors.indigo,
                                      isDark,
                                    ),
                                ],
                              ),
                            ),
                          // Confidence Progress
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: confidence.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: isDark
                                        ? Colors.white12
                                        : Colors.black.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isMatched
                                          ? BrandTokens.stitchSafe
                                          : BrandTokens.stitchWarning,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$confidencePercent% tương đồng',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (!isMatched && onOpenPeoplePage != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.person_add_alt_1_rounded,
                                    size: 16),
                                label: const Text('Đăng ký vào hệ thống'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: BrandTokens.stitchCriticalFg,
                                  side: BorderSide(
                                    color: BrandTokens.stitchCriticalBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BrandTokens.buttonRadius,
                                    ),
                                  ),
                                ),
                                onPressed: onOpenPeoplePage,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),

              // 5. Bottom Action Buttons
              Row(
                children: [
                  if (onRescan != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Quét lại'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(BrandTokens.buttonRadius),
                          ),
                        ),
                        onPressed: onRescan,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                      label: const Text('Hồ sơ khuôn mặt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? BrandTokens.darkPrimary
                            : BrandTokens.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                        ),
                      ),
                      onPressed: onOpenPeoplePage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : color,
        ),
      ),
    );
  }
}
