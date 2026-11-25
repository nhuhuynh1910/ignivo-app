import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/brand_tokens.dart';
import '../fireguard/face_widgets.dart';

class FaceScanResultSheet extends StatelessWidget {
  const FaceScanResultSheet({
    super.key,
    required this.result,
    required this.api,
    this.onOpenPeoplePage,
    this.onRescan,
  });

  final Map<String, dynamic> result;
  final FireguardApiService api;
  final VoidCallback? onOpenPeoplePage;
  final VoidCallback? onRescan;

  Uint8List? _decodeAnnotatedImage() {
    final raw = result['annotated_image']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final idx = raw.indexOf('base64,');
    final b64 = idx >= 0 ? raw.substring(idx + 7) : raw;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  void _openZoomImage(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            title: const Text('Ảnh đối chiếu gương mặt'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final facesDetected = (result['faces_detected'] as num?)?.toInt() ?? 0;
    final rawResults = (result['results'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final snapshotPath = result['snapshot']?.toString();
    final annotatedBytes = _decodeAnnotatedImage();
    final verificationNote = result['verification_note']?.toString() ??
        'Chỉ hỗ trợ xác minh danh tính, không tự kết luận xâm nhập (BR-06).';

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
                          'Kết quả đối chiếu gương mặt',
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
              const SizedBox(height: 12),

              // BR-06 Verification Notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? BrandTokens.darkSurfaceVariant
                      : BrandTokens.brandTint.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark
                          ? BrandTokens.darkPrimary
                          : BrandTokens.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verificationNote,
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Annotated image (preferred) or snapshot fallback
              if (annotatedBytes != null) ...[
                GestureDetector(
                  onTap: () => _openZoomImage(context, annotatedBytes),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                        child: Image.memory(
                          annotatedBytes,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Phóng to',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (snapshotPath != null && snapshotPath.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  child: GuardFaceImage(
                    api: api,
                    path: snapshotPath,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholderIcon: Icons.photo_camera_outlined,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (facesDetected == 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? BrandTokens.stitchDarkWarningBg
                        : BrandTokens.stitchWarningBg,
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(
                      color: BrandTokens.stitchWarning.withValues(alpha: 0.4),
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
                                    ? BrandTokens.stitchDarkWarningFg
                                    : BrandTokens.stitchWarningFg,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Không phát hiện khuôn mặt rõ nét trong khung hình lúc này. Hãy kiểm tra góc nhìn hoặc ánh sáng trước camera.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark
                                    ? BrandTokens.stitchDarkWarningFg
                                        .withValues(alpha: 0.85)
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
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final face = rawResults[index];
                    final isMatched = face['matched'] == true;
                    final name = isMatched
                        ? (face['name']?.toString() ?? 'Đã đăng ký')
                        : 'Chưa khớp danh sách đăng ký';
                    final role = face['role']?.toString();
                    final groupTag = face['group_tag']?.toString();
                    final confidence =
                        (face['confidence'] as num?)?.toDouble() ?? 0.0;
                    final confidencePercent =
                        (confidence * 100).toStringAsFixed(1);

                    final cardColor = isMatched
                        ? (isDark
                              ? BrandTokens.stitchDarkOnlineBg
                              : BrandTokens.stitchOnlineBg)
                        : (isDark
                              ? BrandTokens.stitchDarkWarningBg
                              : BrandTokens.stitchWarningBg);
                    final accentColor = isMatched
                        ? BrandTokens.stitchSafe
                        : BrandTokens.stitchWarning;
                    final fgColor = isMatched
                        ? (isDark
                              ? BrandTokens.stitchDarkOnlineFg
                              : BrandTokens.stitchOnlineFg)
                        : (isDark
                              ? BrandTokens.stitchDarkWarningFg
                              : BrandTokens.stitchWarningFg);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
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
                                    : Icons.person_search_rounded,
                                color: accentColor,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: fgColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isMatched ? 'Đã khớp' : 'Cần xác minh',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: fgColor,
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
                                    buildFaceGroupBadge(
                                      groupTag,
                                      isDark: isDark,
                                    ),
                                ],
                              ),
                            ),
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
                                      accentColor,
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
                          if (!isMatched &&
                              api.canConfigure &&
                              onOpenPeoplePage != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 16,
                                ),
                                label: const Text('Đăng ký vào hệ thống'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: fgColor,
                                  side: BorderSide(
                                    color: accentColor.withValues(alpha: 0.5),
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
                    if (onOpenPeoplePage != null) const SizedBox(width: 10),
                  ],
                  if (onOpenPeoplePage != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.people_alt_outlined, size: 18),
                        label: const Text('Hồ sơ gương mặt'),
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
