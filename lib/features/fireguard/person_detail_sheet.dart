import 'package:flutter/material.dart';
import '../../core/services/fireeye_api_service.dart';
import '../../core/theme/brand_tokens.dart';
import 'people_page.dart' show FireeyeImage;

String getAngleTypeLabel(String? angle) {
  switch (angle) {
    case 'FRONTAL':
      return 'Chính diện';
    case 'LEFT_PROFILE':
      return 'Nghiêng trái';
    case 'RIGHT_PROFILE':
      return 'Nghiêng phải';
    case 'WITH_GLASSES':
      return 'Đeo kính';
    case 'UPWARD':
      return 'Ngẩng đầu';
    case 'DOWNWARD':
      return 'Cúi đầu';
    default:
      return 'Góc bổ sung';
  }
}

class PersonDetailSheet extends StatefulWidget {
  const PersonDetailSheet({
    super.key,
    required this.person,
    required this.eye,
    required this.onAddSample,
    required this.onDelete,
  });

  final Map<String, dynamic> person;
  final FireeyeApiService eye;
  final Future<void> Function() onAddSample;
  final Future<void> Function() onDelete;

  @override
  State<PersonDetailSheet> createState() => _PersonDetailSheetState();
}

class _PersonDetailSheetState extends State<PersonDetailSheet> {
  late Future<List<Map<String, dynamic>>> _samplesFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  void _loadSamples() {
    _samplesFuture = widget.eye.getPersonSamples(widget.person['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final person = widget.person;
    final name = person['name']?.toString() ?? 'Thành viên';
    final groupTag = person['group_tag']?.toString() ?? 'FAMILY';
    final consentedAt = person['consented_at']?.toString();
    final avatarPath = person['avatar_path']?.toString();

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
                  Expanded(
                    child: Text(
                      'Hồ sơ khuôn mặt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
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

              // 3. User Identity Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? BrandTokens.darkSurfaceVariant
                      : BrandTokens.brandTint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  border: Border.all(
                    color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar / Photo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? BrandTokens.darkPrimary
                                : BrandTokens.brandPrimary)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? BrandTokens.darkPrimary
                              : BrandTokens.brandPrimary,
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: (avatarPath != null && avatarPath.isNotEmpty)
                            ? FireeyeImage(
                                eye: widget.eye,
                                path: avatarPath,
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: isDark
                                    ? BrandTokens.darkPrimary
                                    : BrandTokens.brandPrimary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildGroupChip(groupTag, isDark),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            consentedAt != null
                                ? 'Đã xác nhận đồng thuận: $consentedAt'
                                : 'Chưa có cờ đồng thuận hợp lệ',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Multi-angle Samples Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bộ sưu tập góc mặt đã học',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  if (widget.eye.canConfigure)
                    TextButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text('Thêm góc'),
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await widget.onAddSample();
                                if (mounted) {
                                  setState(_loadSamples);
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                ],
              ),
              const SizedBox(height: 8),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _samplesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Không thể tải danh sách mẫu: ${snapshot.error}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }

                  final samples = snapshot.data ?? [];
                  if (samples.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BrandTokens.darkSurfaceVariant
                            : Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                      ),
                      child: Text(
                        'Chưa có mẫu góc bổ sung. Bấm "Thêm góc" để cải thiện độ chính xác khi camera quan sát từ góc chéo.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: samples.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final s = samples[index];
                        final imgPath = s['image_path']?.toString() ?? '';
                        final angle = s['angle_type']?.toString();
                        final score = (s['quality_score'] as num?)?.toDouble() ?? 1.0;
                        final scorePercent = (score * 100).toStringAsFixed(0);

                        return Container(
                          width: 110,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? BrandTokens.darkSurfaceVariant
                                : Colors.grey.shade50,
                            borderRadius:
                                BorderRadius.circular(BrandTokens.cardRadius),
                            border: Border.all(
                              color: isDark
                                  ? BrandTokens.darkBorder
                                  : BrandTokens.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imgPath.isNotEmpty
                                      ? FireeyeImage(
                                          eye: widget.eye,
                                          path: imgPath,
                                        )
                                      : const Icon(Icons.face, size: 40),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                getAngleTypeLabel(angle),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Nét: $scorePercent%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: BrandTokens.stitchSafe,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 5. Actions Footer
              if (widget.eye.canConfigure) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_remove_outlined,
                      color: BrandTokens.stitchCritical),
                  label: const Text(
                    'Xóa hồ sơ & Rút lại sự đồng thuận',
                    style: TextStyle(color: BrandTokens.stitchCritical),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(
                      color: BrandTokens.stitchCritical.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(BrandTokens.buttonRadius),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await widget.onDelete();
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupChip(String tag, bool isDark) {
    Color bg;
    Color fg;
    String label;

    switch (tag) {
      case 'STAFF':
        bg = Colors.blue.withValues(alpha: 0.2);
        fg = Colors.blue.shade600;
        label = 'Nhân viên';
        break;
      case 'GUEST':
        bg = Colors.orange.withValues(alpha: 0.2);
        fg = Colors.orange.shade800;
        label = 'Khách';
        break;
      default:
        bg = BrandTokens.stitchSafe.withValues(alpha: 0.2);
        fg = BrandTokens.stitchSafe;
        label = 'Gia đình';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
