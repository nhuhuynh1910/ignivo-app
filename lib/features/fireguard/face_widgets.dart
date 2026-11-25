import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/face_notification_service.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/brand_tokens.dart';
import 'eye_events_page.dart';
import 'people_page.dart';

/// Danh sách góc mặt chuẩn được backend FireGuard hỗ trợ (VALID_ANGLES).
const List<({String code, String label})> kFaceAngleOptions = [
  (code: 'FRONTAL', label: 'Chính diện'),
  (code: 'LEFT_PROFILE', label: 'Nghiêng trái'),
  (code: 'RIGHT_PROFILE', label: 'Nghiêng phải'),
  (code: 'GLASSES', label: 'Đeo kính'),
  (code: 'MASK', label: 'Đeo khẩu trang'),
  (code: 'OTHER', label: 'Góc khác'),
];

const List<({String code, String label})> kFaceGroupOptions = [
  (code: 'FAMILY', label: 'Gia đình'),
  (code: 'STAFF', label: 'Nhân viên'),
  (code: 'GUEST', label: 'Khách'),
];

const List<String> kFaceRoleOptions = [
  'Family',
  'Operator',
  'Admin',
  'Security',
];

String faceAngleLabel(String? angle) {
  switch (angle?.toUpperCase()) {
    case 'FRONTAL':
      return 'Chính diện';
    case 'LEFT_PROFILE':
      return 'Nghiêng trái';
    case 'RIGHT_PROFILE':
      return 'Nghiêng phải';
    case 'GLASSES':
    case 'WITH_GLASSES':
      return 'Đeo kính';
    case 'MASK':
      return 'Đeo khẩu trang';
    case 'UPWARD':
      return 'Ngẩng đầu';
    case 'DOWNWARD':
      return 'Cúi đầu';
    default:
      return 'Góc khác';
  }
}

String faceGroupLabel(String? tag) {
  switch (tag?.toUpperCase()) {
    case 'STAFF':
      return 'Nhân viên';
    case 'GUEST':
      return 'Khách';
    case 'FAMILY':
    default:
      return 'Gia đình';
  }
}

({Color bg, Color fg, String label}) faceGroupStyle(
  String? tag, {
  required bool isDark,
}) {
  switch (tag?.toUpperCase()) {
    case 'STAFF':
      return (
        bg: isDark
            ? BrandTokens.darkBrandTint
            : BrandTokens.brandAccent.withValues(alpha: 0.12),
        fg: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
        label: 'Nhân viên',
      );
    case 'GUEST':
      return (
        bg: isDark
            ? BrandTokens.stitchDarkWarningBg
            : BrandTokens.stitchWarningBg,
        fg: isDark
            ? BrandTokens.stitchDarkWarningFg
            : BrandTokens.stitchWarningFg,
        label: 'Khách',
      );
    case 'FAMILY':
    default:
      return (
        bg: isDark
            ? BrandTokens.stitchDarkOnlineBg
            : BrandTokens.stitchOnlineBg,
        fg: isDark
            ? BrandTokens.stitchDarkOnlineFg
            : BrandTokens.stitchOnlineFg,
        label: 'Gia đình',
      );
  }
}

Widget buildFaceGroupBadge(String? tag, {required bool isDark}) {
  final style = faceGroupStyle(tag, isDark: isDark);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: style.bg,
      borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
    ),
    child: Text(
      style.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: style.fg,
      ),
    ),
  );
}

/// Tải ảnh gương mặt/snapshot thông qua proxy xác thực của FireGuard (`/faces/media/...`).
class GuardFaceImage extends StatefulWidget {
  const GuardFaceImage({
    super.key,
    required this.api,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderIcon = Icons.person_rounded,
  });

  final FireguardApiService api;
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData placeholderIcon;

  @override
  State<GuardFaceImage> createState() => _GuardFaceImageState();
}

class _GuardFaceImageState extends State<GuardFaceImage> {
  late Future<Uint8List> _future = widget.api.getFaceMedia(widget.path);

  @override
  void didUpdateWidget(covariant GuardFaceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.api != widget.api) {
      _future = widget.api.getFaceMedia(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: isDark ? BrandTokens.darkSurfaceVariant : BrandTokens.brandTint,
            alignment: Alignment.center,
            child: Icon(
              widget.placeholderIcon,
              size: 22,
              color: isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary,
            ),
          );
        }
        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.width ?? 48,
            height: widget.height ?? 48,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, _, _) => Icon(widget.placeholderIcon, size: 22),
        );
      },
    );
  }
}

/// Bottom sheet cài đặt thông báo nhận diện gương mặt (dùng chung cho Cài đặt & Hồ sơ gương mặt).
Future<void> showFaceNotificationSettingsSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final svc = FaceNotificationService.instance;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: isDark
                            ? BrandTokens.darkPrimary
                            : BrandTokens.brandNavy,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cài đặt thông báo nhận diện',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tùy chỉnh thông báo nổi khi AI đối chiếu gương mặt qua camera. Kết quả chỉ hỗ trợ xác minh danh tính (BR-06).',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Thông báo người quen'),
                    subtitle: const Text(
                      'Hiện thông báo xác nhận khi AI khớp người đã đăng ký',
                    ),
                    trailing: Switch(
                      value: svc.notifyKnown,
                      onChanged: (v) async {
                        await svc.setNotifyKnown(v);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Thông báo khuôn mặt chưa khớp'),
                    subtitle: const Text(
                      'Hiện thông báo cần xác minh khi gặp người chưa đăng ký',
                    ),
                    trailing: Switch(
                      value: svc.notifyUnknown,
                      onChanged: (v) async {
                        await svc.setNotifyUnknown(v);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Xong'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Thẻ lối vào nhanh tính năng gương mặt theo ngữ cảnh (Camera / Cảnh báo / Trang chủ).
class FaceQuickAccessCard extends StatelessWidget {
  const FaceQuickAccessCard({
    super.key,
    required this.api,
    this.cameras = const [],
    this.primaryIsHistory = false,
    this.compact = false,
  });

  final FireguardApiService api;
  final List<Map<String, dynamic>> cameras;
  final bool primaryIsHistory;
  final bool compact;

  void _openPeople(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PeoplePage(api: api, cameras: cameras),
      ),
    );
  }

  void _openEvents(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaceEventsPage(api: api, cameras: cameras),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;
    final title = primaryIsHistory
        ? 'Lịch sử nhận diện gương mặt'
        : 'Hồ sơ gương mặt';
    final subtitle = primaryIsHistory
        ? 'Xem sự kiện đã khớp và cần xác minh'
        : 'Quản lý người quen, góc mặt và Watcher';
    final secondaryLabel = primaryIsHistory ? 'Hồ sơ' : 'Lịch sử';
    final secondaryIcon = primaryIsHistory
        ? Icons.people_alt_outlined
        : Icons.history_rounded;

    return Material(
      color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
      borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        onTap: () =>
            primaryIsHistory ? _openEvents(context) : _openPeople(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 7 : 9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  primaryIsHistory
                      ? Icons.history_rounded
                      : Icons.face_retouching_natural_rounded,
                  size: compact ? 18 : 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  backgroundColor: accent.withValues(alpha: 0.08),
                  foregroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.badgeRadius),
                  ),
                ),
                onPressed: () => primaryIsHistory
                    ? _openPeople(context)
                    : _openEvents(context),
                icon: Icon(secondaryIcon, size: 15),
                label: Text(
                  secondaryLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? BrandTokens.darkTextTertiary
                    : BrandTokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
