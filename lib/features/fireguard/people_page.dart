import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/face_notification_service.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../widgets/interactive_card.dart';
import 'eye_events_page.dart';
import 'face_widgets.dart';
import 'person_detail_sheet.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({
    super.key,
    required this.api,
    this.cameras = const [],
  });

  final FireguardApiService api;
  final List<Map<String, dynamic>> cameras;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _cameras = [];
  Map<String, dynamic>? _status;
  String _selectedGroup = 'ALL';
  String _searchQuery = '';
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cameras = widget.cameras;
    unawaited(FaceNotificationService.instance.initialize());
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.api.getFacePeople(),
        widget.api.getFaceWatchStatus().catchError(
          (e) => <String, dynamic>{
            'available': false,
            'running': false,
            'error': '$e',
          },
        ),
        if (_cameras.isEmpty)
          widget.api.getCameras().catchError((_) => <Map<String, dynamic>>[])
        else
          Future.value(_cameras),
      ]);
      if (!mounted) return;
      setState(() {
        _people = results[0] as List<Map<String, dynamic>>;
        _status = results[1] as Map<String, dynamic>;
        _cameras = results[2] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRegisterSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FaceRegisterSheet(
        api: widget.api,
        cameras: _cameras,
        isWatcherAvailable: _status?['available'] == true,
      ),
    );
    if (created == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng ký hồ sơ gương mặt thành công.')),
      );
    }
  }

  Future<void> _addSample(Map<String, dynamic> person) async {
    final res = await showModalBottomSheet<({String angle, Uint8List? image, int? cameraId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFaceSampleSheet(
        personName: person['name']?.toString() ?? 'Thành viên',
        cameras: _cameras,
      ),
    );
    if (res == null || !mounted) return;

    await _act(() async {
      await widget.api.addFaceSample(
        person['id'] as int,
        angleType: res.angle,
        image: res.image,
        cameraId: res.cameraId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã bổ sung mẫu ${faceAngleLabel(res.angle)} cho ${person['name']}.',
          ),
        ),
      );
    });
  }

  Future<void> _delete(Map<String, dynamic> person) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa hồ sơ ${person['name']}?'),
        content: const Text(
          'Xóa dữ liệu gương mặt và ngừng đối chiếu người này. Lịch sử sự kiện cũ vẫn được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BrandTokens.stitchCritical,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa và ngừng đối chiếu'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _act(() => widget.api.deleteFacePerson(person['id'] as int));
    }
  }

  List<Map<String, dynamic>> get _filteredPeople {
    final q = _searchQuery.trim().toLowerCase();
    return _people.where((p) {
      if (_selectedGroup != 'ALL' &&
          (p['group_tag']?.toString().toUpperCase() ?? 'FAMILY') !=
              _selectedGroup) {
        return false;
      }
      if (q.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final role = (p['role'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !role.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasUser = widget.api.currentUser != null;
    final accessDenied = hasUser && !widget.api.canAccessFaces;
    final filtered = _filteredPeople;

    return Scaffold(
      appBar: ignivoDetailAppBar(
        context,
        title: 'Hồ sơ gương mặt',
        actions: [
          IconButton(
            tooltip: 'Lịch sử nhận diện',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FaceEventsPage(api: widget.api, cameras: _cameras),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cài đặt thông báo nhận diện',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => showFaceNotificationSettingsSheet(context),
          ),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
      body: accessDenied
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? BrandTokens.darkCriticalBg
                          : BrandTokens.criticalBg,
                      borderRadius:
                          BorderRadius.circular(BrandTokens.cardRadius),
                      border: Border.all(
                        color: isDark
                            ? BrandTokens.darkCriticalBorder
                            : BrandTokens.criticalBorder,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: BrandTokens.stitchCritical,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tài khoản hiện tại không có quyền truy cập dữ liệu sinh trắc học gương mặt (BR-24).',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (_error != null) _buildErrorBanner(isDark),
                      _buildWatcherCard(isDark),
                      const SizedBox(height: 16),
                      _buildRegistryHeader(isDark),
                      const SizedBox(height: 12),
                      if (_people.isNotEmpty) ...[
                        _buildSearchAndFilters(isDark),
                        const SizedBox(height: 12),
                      ],
                      if (_people.isEmpty)
                        _buildEmptyRegistry(isDark)
                      else if (filtered.isEmpty)
                        _buildEmptySearch(isDark)
                      else
                        for (final person in filtered)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildPersonCard(person, isDark),
                          ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkCriticalBg : BrandTokens.criticalBg,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark
              ? BrandTokens.darkCriticalBorder
              : BrandTokens.criticalBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: BrandTokens.stitchCritical,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? BrandTokens.stitchDarkCriticalFg
                    : BrandTokens.stitchCriticalFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatcherCard(bool isDark) {
    final available = _status?['available'] == true;
    final running = _status?['running'] == true;
    final monitoredCam = _status?['monitored_camera'] as Map?;
    final camLabel = monitoredCam != null
        ? '${monitoredCam['name'] ?? 'Camera #${monitoredCam['id']}'}'
              '${monitoredCam['area'] != null ? ' (${monitoredCam['area']})' : ''}'
        : 'Camera chính';
    final interval = _status?['scan_interval'];
    final statusSubtitle = available
        ? '${running ? 'Đang bật' : 'Đang tắt'} · $camLabel'
              '${interval != null ? ' · ${interval}s/lần' : ''}'
        : (_status?['error']?.toString() ?? 'Chưa sẵn sàng');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
        boxShadow: BrandTokens.softShadow(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (running
                          ? BrandTokens.stitchSafe
                          : (isDark
                                ? BrandTokens.darkPrimary
                                : BrandTokens.brandPrimary))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 20,
                  color: running
                      ? BrandTokens.stitchSafe
                      : (isDark
                            ? BrandTokens.darkPrimary
                            : BrandTokens.brandPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theo dõi gương mặt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: !available
                            ? BrandTokens.stitchCriticalFg
                            : (isDark
                                  ? BrandTokens.darkTextSecondary
                                  : BrandTokens.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: running,
                onChanged: _busy || !widget.api.canConfigure || !available
                    ? null
                    : (v) => _act(() => widget.api.setFaceWatch(v)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chỉ hỗ trợ xác minh danh tính, không kích hoạt còi báo cháy.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark
                  ? BrandTokens.darkTextTertiary
                  : BrandTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistryHeader(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                'Đã đăng ký (${_people.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!widget.api.canConfigure) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? BrandTokens.darkSurfaceVariant
                        : BrandTokens.brandTint,
                    borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
                  ),
                  child: Text(
                    'Chỉ xem',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? BrandTokens.darkTextSecondary
                          : BrandTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.api.canConfigure)
          FilledButton.icon(
            onPressed: _busy ? null : _openRegisterSheet,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Đăng ký'),
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? BrandTokens.darkPrimary
                  : BrandTokens.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    final counts = <String, int>{
      'ALL': _people.length,
      'FAMILY': _people
          .where((p) => (p['group_tag'] ?? 'FAMILY') == 'FAMILY')
          .length,
      'STAFF': _people.where((p) => p['group_tag'] == 'STAFF').length,
      'GUEST': _people.where((p) => p['group_tag'] == 'GUEST').length,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc vai trò...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            isDense: true,
            filled: true,
            fillColor: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
              borderSide: BorderSide(
                color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
              borderSide: BorderSide(
                color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _groupFilterChip('ALL', 'Tất cả (${counts['ALL']})', isDark),
              const SizedBox(width: 8),
              for (final g in kFaceGroupOptions) ...[
                _groupFilterChip(
                  g.code,
                  '${g.label} (${counts[g.code] ?? 0})',
                  isDark,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupFilterChip(String code, String label, bool isDark) {
    final selected = _selectedGroup == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _selectedGroup = code),
      selectedColor: (isDark
              ? BrandTokens.darkPrimary
              : BrandTokens.brandPrimary)
          .withValues(alpha: 0.14),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary)
            : (isDark
                  ? BrandTokens.darkTextSecondary
                  : BrandTokens.textSecondary),
      ),
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> person, bool isDark) {
    final avatarPath = person['avatar_path']?.toString();
    final groupTag = person['group_tag']?.toString() ?? 'FAMILY';
    final role = person['role']?.toString().trim();
    final showRole = role != null &&
        role.isNotEmpty &&
        role.toLowerCase() != groupTag.toLowerCase() &&
        role.toLowerCase() != faceGroupLabel(groupTag).toLowerCase();
    final consentedAt = person['consented_at']?.toString();
    final samplesCount = person['samples_count'];

    return InteractiveCard(
      borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
      padding: const EdgeInsets.all(14),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PersonDetailSheet(
            person: person,
            api: widget.api,
            onAddSample: () => _addSample(person),
            onDelete: () => _delete(person),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark
                      ? BrandTokens.darkPrimary
                      : BrandTokens.brandPrimary)
                  .withValues(alpha: 0.1),
              border: Border.all(
                color: faceGroupStyle(groupTag, isDark: isDark)
                    .fg
                    .withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: (avatarPath != null && avatarPath.isNotEmpty)
                  ? GuardFaceImage(
                      api: widget.api,
                      path: avatarPath,
                      width: 52,
                      height: 52,
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 26,
                      color: isDark
                          ? BrandTokens.darkPrimary
                          : BrandTokens.brandPrimary,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${person['name'] ?? 'Thành viên'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    buildFaceGroupBadge(groupTag, isDark: isDark),
                    if (showRole)
                      Text(
                        '· $role',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? BrandTokens.darkTextSecondary
                              : BrandTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (samplesCount != null || consentedAt == null) ...[
                  const SizedBox(height: 4),
                  if (samplesCount != null)
                    Text(
                      '$samplesCount góc mặt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? BrandTokens.darkPrimary
                            : BrandTokens.brandPrimary,
                      ),
                    ),
                  if (consentedAt == null)
                    const Text(
                      'Thiếu đồng thuận — cần đăng ký lại',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: BrandTokens.stitchWarningFg,
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (widget.api.canConfigure)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Thêm góc mặt',
                  onPressed: _busy ? null : () => _addSample(person),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Xóa hồ sơ và rút lại đồng ý',
                  onPressed: _busy ? null : () => _delete(person),
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    size: 20,
                    color: BrandTokens.stitchCritical,
                  ),
                ),
              ],
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? BrandTokens.darkTextTertiary
                  : BrandTokens.textTertiary,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyRegistry(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: isDark
                ? BrandTokens.darkTextTertiary
                : BrandTokens.textTertiary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có hồ sơ gương mặt',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm thành viên để camera nhận diện khi xuất hiện.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? BrandTokens.darkTextSecondary
                  : BrandTokens.textSecondary,
            ),
          ),
          if (widget.api.canConfigure) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _openRegisterSheet,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Đăng ký ngay'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySearch(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'Không tìm thấy hồ sơ phù hợp',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _selectedGroup = 'ALL';
                _searchQuery = '';
              });
            },
            child: const Text('Xóa bộ lọc'),
          ),
        ],
      ),
    );
  }
}

class _FaceRegisterSheet extends StatefulWidget {
  const _FaceRegisterSheet({
    required this.api,
    required this.cameras,
    required this.isWatcherAvailable,
  });

  final FireguardApiService api;
  final List<Map<String, dynamic>> cameras;
  final bool isWatcherAvailable;

  @override
  State<_FaceRegisterSheet> createState() => _FaceRegisterSheetState();
}

class _FaceRegisterSheetState extends State<_FaceRegisterSheet> {
  final _nameCtrl = TextEditingController();
  bool _fromPi = false;
  int? _selectedCameraId;
  Uint8List? _image;
  String _role = 'Family';
  String _groupTag = 'FAMILY';
  String _angleType = 'FRONTAL';
  bool _consent = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        setState(() => _error = 'Ảnh tối đa 8 MB.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _fromPi = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không mở được ảnh/camera. Kiểm tra quyền truy cập.';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || (!_fromPi && _image == null) || !_consent) {
      setState(() {
        _error = 'Vui lòng nhập họ tên, chọn nguồn ảnh và xác nhận đồng thuận.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.registerFace(
        name: _nameCtrl.text,
        role: _role,
        groupTag: _groupTag,
        angleType: _angleType,
        consent: _consent,
        image: _fromPi ? null : _image,
        cameraId: _fromPi ? _selectedCameraId : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đăng ký hồ sơ gương mặt',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              if (!widget.isWatcherAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Dịch vụ nhận diện đang tắt, sẽ kiểm tra lại khi gửi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: BrandTokens.stitchWarningFg,
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                key: const Key('person-name'),
                controller: _nameCtrl,
                enabled: !_submitting,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Họ và tên',
                  hintText: 'Ví dụ: Nguyễn Văn A',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Vai trò',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.inputRadius),
                        ),
                      ),
                      items: kFaceRoleOptions
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _role = v ?? 'Family'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _angleType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Góc mặt ban đầu',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.inputRadius),
                        ),
                      ),
                      items: kFaceAngleOptions
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.code,
                              child: Text(
                                a.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _angleType = v ?? 'FRONTAL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Nhóm:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  for (final g in kFaceGroupOptions)
                    ChoiceChip(
                      label: Text(g.label),
                      selected: _groupTag == g.code,
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() => _groupTag = g.code),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text(
                      'Từ điện thoại',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: Icon(Icons.photo_camera_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(
                      'Chụp từ Camera Pi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: Icon(Icons.videocam_outlined, size: 18),
                  ),
                ],
                selected: {_fromPi},
                onSelectionChanged: _submitting
                    ? null
                    : (s) => setState(() => _fromPi = s.first),
              ),
              const SizedBox(height: 12),
              if (_fromPi) ...[
                DropdownButtonFormField<int?>(
                  initialValue: _selectedCameraId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Camera chụp trên Pi',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(BrandTokens.inputRadius),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Camera chính'),
                    ),
                    for (final c in widget.cameras)
                      DropdownMenuItem<int?>(
                        value: c['id'] as int?,
                        child: Text(
                          '#${c['id']} ${c['name']}${c['area'] != null ? ' · ${c['area']}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _selectedCameraId = v),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đứng một mình, nhìn thẳng vào camera khi bấm đăng ký.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? BrandTokens.darkTextSecondary
                        : BrandTokens.textSecondary,
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Chọn ảnh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Chụp ảnh'),
                    ),
                  ],
                ),
                if (_image != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    child: Image.memory(
                      _image!,
                      height: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              CheckboxListTile(
                key: const Key('face-consent'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Xác nhận chủ thể đồng ý lưu dữ liệu gương mặt trên thiết bị để nhận diện.',
                  style: TextStyle(fontSize: 12.5),
                ),
                value: _consent,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _consent = v == true),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting ||
                        !_consent ||
                        _nameCtrl.text.trim().isEmpty ||
                        (!_fromPi && _image == null)
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.buttonRadius),
                  ),
                ),
                child: Text(
                  _submitting ? 'Đang xử lý…' : 'Đăng ký khuôn mặt',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFaceSampleSheet extends StatefulWidget {
  const _AddFaceSampleSheet({
    required this.personName,
    required this.cameras,
  });

  final String personName;
  final List<Map<String, dynamic>> cameras;

  @override
  State<_AddFaceSampleSheet> createState() => _AddFaceSampleSheetState();
}

class _AddFaceSampleSheetState extends State<_AddFaceSampleSheet> {
  String _angle = 'LEFT_PROFILE';
  int? _cameraId;

  Future<void> _pickAndPop(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).pop((angle: _angle, image: bytes, cameraId: null));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Thêm mẫu góc mặt · ${widget.personName}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _angle,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Góc mặt / Trạng thái',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.inputRadius),
                  ),
                ),
                items: kFaceAngleOptions
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.code,
                        child: Text(a.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _angle = v ?? 'OTHER'),
              ),
              const SizedBox(height: 12),
              if (widget.cameras.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  initialValue: _cameraId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Camera Pi',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(BrandTokens.inputRadius),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Camera chính'),
                    ),
                    for (final c in widget.cameras)
                      DropdownMenuItem<int?>(
                        value: c['id'] as int?,
                        child: Text('#${c['id']} ${c['name']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cameraId = v),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Chụp từ Camera Pi'),
                onPressed: () => Navigator.of(context).pop(
                  (angle: _angle, image: null, cameraId: _cameraId),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Chụp điện thoại'),
                      onPressed: () => _pickAndPop(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Thư viện ảnh'),
                      onPressed: () => _pickAndPop(ImageSource.gallery),
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
}
