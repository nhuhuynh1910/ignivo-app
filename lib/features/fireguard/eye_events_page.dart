import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/interactive_card.dart';
import 'face_widgets.dart';
import 'monitor_widgets.dart';
import 'people_page.dart';

typedef EyeEventsPage = FaceEventsPage;

String faceEventLabel(dynamic value) =>
    const {
      'KNOWN_PERSON': 'Đã khớp hồ sơ',
      'UNKNOWN_PERSON': 'Khuôn mặt chưa khớp (Cần xác minh)',
    }[value?.toString().toUpperCase()] ??
    '$value';

/// Màn hình độc lập Lịch sử nhận diện gương mặt (mở từ Cài đặt, Camera hoặc thông báo nổi).
class FaceEventsPage extends StatelessWidget {
  const FaceEventsPage({
    super.key,
    required this.api,
    this.cameras = const [],
  });

  final FireguardApiService api;
  final List<Map<String, dynamic>> cameras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ignivoDetailAppBar(
        context,
        title: 'Lịch sử nhận diện gương mặt',
        subtitle: 'Nhật ký xác minh danh tính theo camera',
        actions: [
          if (api.canAccessFaces)
            IconButton(
              tooltip: 'Hồ sơ gương mặt',
              icon: const Icon(Icons.people_alt_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PeoplePage(api: api, cameras: cameras),
                ),
              ),
            ),
        ],
      ),
      body: FaceEventsView(
        api: api,
        cameras: cameras,
        showPeopleButton: false,
      ),
    );
  }
}

/// Nội dung danh sách sự kiện gương mặt dùng chung cho cả [FaceEventsPage] và tab Cảnh báo.
class FaceEventsView extends StatefulWidget {
  const FaceEventsView({
    super.key,
    required this.api,
    this.cameras = const [],
    this.showPeopleButton = true,
    this.refreshListenable,
  });

  final FireguardApiService api;
  final List<Map<String, dynamic>> cameras;
  final bool showPeopleButton;
  final Listenable? refreshListenable;

  @override
  State<FaceEventsView> createState() => _FaceEventsViewState();
}

class _FaceEventsViewState extends State<FaceEventsView> {
  List<Map<String, dynamic>> _events = [];
  bool _busy = false;
  String? _error;
  String? _type;
  int? _cameraId;

  @override
  void initState() {
    super.initState();
    widget.refreshListenable?.addListener(_onExternalRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant FaceEventsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_onExternalRefresh);
      widget.refreshListenable?.addListener(_onExternalRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.getFaceEvents(
        eventType: _type,
        cameraId: _cameraId,
        limit: 100,
      );
      if (mounted) setState(() => _events = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> event) async {
    final isKnown =
        event['event_type']?.toString().toUpperCase() == 'KNOWN_PERSON';
    final snapshotUrl = event['snapshot_url']?.toString();
    final area = event['area']?.toString() ?? 'Khu vực quan sát';
    final conf = (event['confidence'] as num?)?.toDouble();
    final confText = conf != null ? '${(conf * 100).round()}%' : null;
    final personName = event['person_name']?.toString();
    final timeFormatted = IncidentPresentationHelper.formatTimestamp(
      event['created_at'],
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Scaffold(
            appBar: ignivoDetailAppBar(
              ctx,
              title: isKnown
                  ? (personName ?? 'Đã khớp hồ sơ')
                  : 'Cần xác minh danh tính',
              subtitle:
                  '$area${timeFormatted.isNotEmpty ? ' · $timeFormatted' : ''}',
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isKnown
                            ? (isDark
                                  ? BrandTokens.stitchDarkOnlineBg
                                  : BrandTokens.stitchOnlineBg)
                            : (isDark
                                  ? BrandTokens.stitchDarkWarningBg
                                  : BrandTokens.stitchWarningBg),
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                        border: Border.all(
                          color: (isKnown
                                  ? BrandTokens.stitchSafe
                                  : BrandTokens.stitchWarning)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isKnown
                                ? Icons.verified_user_rounded
                                : Icons.person_search_rounded,
                            color: isKnown
                                ? BrandTokens.stitchSafe
                                : BrandTokens.stitchWarning,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['message']?.toString() ??
                                      faceEventLabel(event['event_type']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Khu vực: $area${confText != null ? ' · Tin cậy: $confText' : ''}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? BrandTokens.darkTextSecondary
                                        : BrandTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (snapshotUrl != null && snapshotUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                        child: GuardFaceImage(
                          api: widget.api,
                          path: snapshotUrl,
                          fit: BoxFit.contain,
                          placeholderIcon: Icons.image_not_supported_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isKnown && widget.api.canConfigure) ...[
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Mở hồ sơ để đăng ký người quen'),
                        onPressed: () {
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => PeoplePage(
                                api: widget.api,
                                cameras: widget.cameras,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BrandTokens.darkSurfaceVariant
                            : BrandTokens.brandTint.withValues(alpha: 0.6),
                        borderRadius:
                            BorderRadius.circular(BrandTokens.cardRadius),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Thông tin nhận diện gương mặt chỉ phục vụ xác minh và không tự kích hoạt báo cháy hay gọi khẩn cấp (BR-06).',
                              style: TextStyle(fontSize: 12, height: 1.4),
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              // Thanh lọc trạng thái + nút mở nhanh Hồ sơ
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip(null, 'Tất cả', isDark),
                            const SizedBox(width: 8),
                            _filterChip('KNOWN_PERSON', 'Đã khớp', isDark),
                            const SizedBox(width: 8),
                            _filterChip(
                              'UNKNOWN_PERSON',
                              'Cần xác minh',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.showPeopleButton) ...[
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
                            borderRadius: BorderRadius.circular(
                              BrandTokens.badgeRadius,
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PeoplePage(
                              api: widget.api,
                              cameras: widget.cameras,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.people_alt_outlined, size: 16),
                        label: const Text(
                          'Hồ sơ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.cameras.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: DropdownButtonFormField<int?>(
                    initialValue: _cameraId,
                    isExpanded: true,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Lọc theo camera',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          BrandTokens.inputRadius,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả camera'),
                      ),
                      for (final c in widget.cameras)
                        DropdownMenuItem<int?>(
                          value: c['id'] as int?,
                          child: Text(
                            '#${c['id']} ${c['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() => _cameraId = v);
                            _load();
                          },
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_events.isEmpty && _error == null)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark
                              ? BrandTokens.darkSurface
                              : BrandTokens.surface,
                          borderRadius: BorderRadius.circular(
                            BrandTokens.cardRadius,
                          ),
                          border: Border.all(
                            color: isDark
                                ? BrandTokens.darkBorder
                                : BrandTokens.border,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 44,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Chưa có sự kiện nhận diện gương mặt nào',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final event in _events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildEventCard(event, isDark),
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

  Widget _filterChip(String? type, String label, bool isDark) {
    final selected = _type == type;
    final accent = isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? accent
              : Theme.of(context).dividerColor.withValues(alpha: 0.15),
          width: selected ? 1.5 : 1,
        ),
      ),
      selectedColor: accent.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? accent : null,
      ),
      onSelected: _busy
          ? null
          : (_) {
              setState(() => _type = type);
              _load();
            },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isDark) {
    final isKnown =
        event['event_type']?.toString().toUpperCase() == 'KNOWN_PERSON';
    final snapshotUrl = event['snapshot_url']?.toString();
    final conf = (event['confidence'] as num?)?.toDouble();
    final confPct = conf != null ? ' · ${(conf * 100).round()}%' : '';
    final area = event['area']?.toString() ?? 'Camera';
    final timeStr = IncidentPresentationHelper.formatTimestamp(
      event['created_at'],
    );

    return InteractiveCard(
      borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
      padding: const EdgeInsets.all(12),
      onTap: () => _open(event),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (snapshotUrl != null && snapshotUrl.isNotEmpty)
                ? GuardFaceImage(
                    api: widget.api,
                    path: snapshotUrl,
                    width: 56,
                    height: 56,
                    placeholderIcon: isKnown
                        ? Icons.verified_user_outlined
                        : Icons.person_search_outlined,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: (isKnown
                            ? BrandTokens.stitchSafe
                            : BrandTokens.stitchWarning)
                        .withValues(alpha: 0.14),
                    child: Icon(
                      isKnown
                          ? Icons.verified_user_rounded
                          : Icons.person_search_rounded,
                      color: isKnown
                          ? BrandTokens.stitchSafe
                          : BrandTokens.stitchWarning,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isKnown
                                ? BrandTokens.stitchSafe
                                : BrandTokens.stitchWarning)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isKnown ? 'ĐÃ KHỚP' : 'CẦN XÁC MINH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isKnown
                              ? BrandTokens.stitchSafe
                              : BrandTokens.stitchWarningFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$area$confPct',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  event['message']?.toString() ??
                      faceEventLabel(event['event_type']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? BrandTokens.darkTextTertiary
                          : BrandTokens.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}
