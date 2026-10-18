import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_logo.dart';
import '../../widgets/edge_status_card.dart';
import '../../widgets/camera_preview_card.dart';
import '../../widgets/camera_status_filters.dart';
import '../../widgets/recent_incident_tile.dart';

/// Trang trưng bày thư viện linh kiện và các màn hình mẫu giao diện IGNIVO Brand UI/UX.
///
/// BẢO MẬT & CÁCH LY HỆ THỐNG:
/// - Trang này CHỈ hoạt động ở môi trường phát triển ([kDebugMode] == true).
/// - Hoàn toàn không tạo kết nối HTTP, WebSocket, không sử dụng SystemSessionController,
///   không phát âm thanh cảnh báo thật hay làm ảnh hưởng phiên giám sát nền.
/// - Cho phép kiểm thử phản ứng giao diện trên cả Light/Dark Mode và Text Scaler 1.0x - 2.0x.
class BrandShowcasePage extends StatefulWidget {
  const BrandShowcasePage({super.key});

  @override
  State<BrandShowcasePage> createState() => _BrandShowcasePageState();
}

class _BrandShowcasePageState extends State<BrandShowcasePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _forceDark = false;
  double _textScale = 1.0;

  // Trạng thái tương tác giả lập trong mock screens
  bool _mockHomeUrgent = false;
  bool _mockIncidentAcked = false;
  bool _mockIncidentSilenced = false;
  bool _mockLoginLoading = false;
  String? _mockLoginError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Brand showcase is only accessible in debug mode.'),
        ),
      );
    }

    final themeData = _forceDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    return Theme(
      data: themeData,
      child: Builder(
        builder: (themedContext) {
          final isDark = Theme.of(themedContext).brightness == Brightness.dark;
          final currentTheme = Theme.of(themedContext);

          return Scaffold(
            backgroundColor: currentTheme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('IGNIVO Brand Showcase'),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.palette_outlined), text: 'Linh kiện'),
                  Tab(icon: Icon(Icons.login), text: 'Đăng nhập'),
                  Tab(icon: Icon(Icons.home_outlined), text: 'Trang chủ mẫu'),
                  Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Chi tiết sự cố'),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: isDark ? 'Chuyển sang nền sáng' : 'Chuyển sang nền tối',
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => setState(() => _forceDark = !_forceDark),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Cỡ chữ (Text Scale)',
                  icon: const Icon(Icons.format_size),
                  initialValue: _textScale,
                  onSelected: (val) => setState(() => _textScale = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 1.0, child: Text('100% (Mặc định)')),
                    const PopupMenuItem(value: 1.5, child: Text('150% (Chữ lớn)')),
                    const PopupMenuItem(value: 2.0, child: Text('200% (Tiếp cận trợ năng)')),
                  ],
                ),
              ],
            ),
            body: MediaQuery(
              data: MediaQuery.of(themedContext).copyWith(
                textScaler: TextScaler.linear(_textScale),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildComponentGallery(isDark),
                  _buildMockLoginScreen(isDark),
                  _buildMockHomeScreen(isDark),
                  _buildMockIncidentDetailScreen(isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 1: THƯ VIỆN LINH KIỆN (COMPONENT GALLERY)
  // ===========================================================================
  Widget _buildComponentGallery(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(BrandTokens.space16),
      children: [
        _buildSectionHeader('1. Logo IGNIVO chuẩn hóa (Badge Card Container)'),
        const SizedBox(height: BrandTokens.space12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            side: BorderSide(color: isDark ? BrandTokens.darkBorder : BrandTokens.border),
          ),
          color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
          child: Padding(
            padding: const EdgeInsets.all(BrandTokens.space16),
            child: Wrap(
              spacing: BrandTokens.space16,
              runSpacing: BrandTokens.space16,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: const [
                IgnivoLogo.mark(size: 64),
                IgnivoLogo.wordmark(width: 180),
                IgnivoLogo.header(),
              ],
            ),
          ),
        ),
        const SizedBox(height: BrandTokens.space24),

        _buildSectionHeader('2. Bảng màu thương hiệu & An toàn'),
        const SizedBox(height: BrandTokens.space12),
        Wrap(
          spacing: BrandTokens.space8,
          runSpacing: BrandTokens.space8,
          children: [
            _buildColorChip('Primary', BrandTokens.brandPrimary, Colors.white),
            _buildColorChip('Navy', BrandTokens.brandNavy, Colors.white),
            _buildColorChip('Cyan', BrandTokens.brandCyan, Colors.black),
            _buildColorChip('Critical', isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg, Colors.white),
            _buildColorChip('High', isDark ? BrandTokens.darkHighFg : BrandTokens.highFg, Colors.white),
            _buildColorChip('Medium', isDark ? BrandTokens.darkMediumFg : BrandTokens.mediumFg, Colors.black),
            _buildColorChip('Normal', isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg, Colors.white),
            _buildColorChip('Stale', isDark ? BrandTokens.darkStaleFg : BrandTokens.staleFg, Colors.white),
          ],
        ),
        const SizedBox(height: BrandTokens.space24),

        _buildSectionHeader('3. Huy hiệu trạng thái nghiệp vụ (Status Badges)'),
        const SizedBox(height: BrandTokens.space12),
        Wrap(
          spacing: BrandTokens.space8,
          runSpacing: BrandTokens.space8,
          children: [
            _buildBadge('CRITICAL (Khẩn cấp)', 'critical', isDark, icon: Icons.local_fire_department),
            _buildBadge('HIGH (Nguy cơ cao)', 'high', isDark, icon: Icons.warning_rounded),
            _buildBadge('MEDIUM (Cảnh báo vừa)', 'medium', isDark, icon: Icons.info_outline),
            _buildBadge('LOW (Bình thường)', 'low', isDark, icon: Icons.check_circle_outline),
            _buildBadge('NORMAL (Đang bảo vệ)', 'normal', isDark, icon: Icons.shield_outlined),
            _buildBadge('ACKNOWLEDGED (Đã xác nhận)', 'acknowledged', isDark, icon: Icons.check),
            _buildBadge('RESOLVED (Đã xử lý)', 'resolved', isDark, icon: Icons.done_all),
            _buildBadge('AI DISMISSED (AI bỏ qua)', 'low', isDark, icon: Icons.visibility_off_outlined),
            _buildBadge('STALE (Dữ liệu cũ)', 'stale', isDark, icon: Icons.history),
          ],
        ),
        const SizedBox(height: BrandTokens.space24),

        _buildSectionHeader('4. Nút bấm & Thành phần tương tác'),
        const SizedBox(height: BrandTokens.space12),
        Wrap(
          spacing: BrandTokens.space12,
          runSpacing: BrandTokens.space12,
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Nút hành động chính'),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Nút phụ viền'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? BrandTokens.darkCriticalBg : BrandTokens.criticalBg,
                foregroundColor: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                side: BorderSide(
                  color: isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder,
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.volume_off),
              label: const Text('Tắt âm còi'),
            ),
          ],
        ),
        const SizedBox(height: BrandTokens.space24),

        _buildSectionHeader('5. Linh kiện Stitch Redesign (Bản 3)'),
        const SizedBox(height: BrandTokens.space12),
        const EdgeStatusCard(
          systemName: 'Nhà (Demo)',
          isOnline: true,
          aiModel: 'Hailo-8L',
          directAlertStatus: 'Kết nối',
          totalCameras: 3,
          onlineCameras: 2,
        ),
        const SizedBox(height: BrandTokens.space16),
        CameraStatusFilters(
          selected: CameraFilterCategory.all,
          onSelected: (_) {},
          totalCount: 3,
          onlineCount: 2,
          offlineCount: 1,
        ),
        const SizedBox(height: BrandTokens.space16),
        const CameraPreviewCard(
          name: 'Phòng khách',
          area: 'Tầng trệt',
          model: 'Hikvision IP-Cam',
          isOnline: true,
          aiStatusText: 'AI đang giám sát thời gian thực',
          aiFps: 25,
          snapshotTime: '10:42',
        ),
        const SizedBox(height: BrandTokens.space12),
        const RecentIncidentTile(
          id: 104,
          title: 'Phát hiện nhiệt bất thường',
          area: 'Nhà bếp',
          timeStr: 'Vừa xong',
          severity: 'high',
          status: 'analyzing',
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: MÀN HÌNH ĐĂNG NHẬP MẪU (MOCK LOGIN SCREEN)
  // ===========================================================================
  Widget _buildMockLoginScreen(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: BrandTokens.space24,
          vertical: BrandTokens.space32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: IgnivoLogo.wordmark(width: 220),
              ),
              const SizedBox(height: BrandTokens.space16),
              Text(
                'Hệ thống Giám sát & Báo cháy IGNIVO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                ),
              ),
              const SizedBox(height: BrandTokens.space8),
              Text(
                'Thiết bị Pi Edge: Nhà mẫu FPT Da Nang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary,
                ),
              ),
              const SizedBox(height: BrandTokens.space24),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Mã khóa hệ thống (System Key)',
                  hintText: 'Nhập mã khóa phần cứng',
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
                  ),
                ),
              ),
              const SizedBox(height: BrandTokens.space16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Tên đăng nhập',
                  hintText: 'guard_operator',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
                  ),
                ),
              ),
              const SizedBox(height: BrandTokens.space16),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
                  ),
                ),
              ),
              if (_mockLoginError != null) ...[
                const SizedBox(height: BrandTokens.space12),
                Container(
                  padding: const EdgeInsets.all(BrandTokens.space12),
                  decoration: BoxDecoration(
                    color: isDark ? BrandTokens.darkCriticalBg : BrandTokens.criticalBg,
                    borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
                    border: Border.all(
                      color: isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                        size: 20,
                      ),
                      const SizedBox(width: BrandTokens.space8),
                      Expanded(
                        child: Text(
                          _mockLoginError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: BrandTokens.space24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _mockLoginLoading
                      ? null
                      : () {
                          setState(() {
                            _mockLoginLoading = true;
                            _mockLoginError = null;
                          });
                          Future.delayed(const Duration(milliseconds: 600), () {
                            if (mounted) {
                              setState(() {
                                _mockLoginLoading = false;
                                _mockLoginError = 'Mô phỏng lỗi: Sai mã khóa phần cứng hoặc mật khẩu';
                              });
                            }
                          });
                        },
                  child: _mockLoginLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Đăng nhập vận hành'),
                ),
              ),
              const SizedBox(height: BrandTokens.space12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _mockLoginError = null;
                  });
                },
                child: const Text('Đổi thiết bị kết nối'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: TRANG CHỦ MẪU (MOCK HOME SCREEN)
  // ===========================================================================
  Widget _buildMockHomeScreen(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(BrandTokens.space16),
      children: [
        // Thanh công cụ chuyển đổi trạng thái mẫu
        Card(
          color: isDark ? BrandTokens.darkSurfaceVariant : BrandTokens.brandTint,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BrandTokens.space16,
              vertical: BrandTokens.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _mockHomeUrgent
                        ? 'Trạng thái: Có sự cố khẩn cấp'
                        : 'Trạng thái: Bình thường an toàn',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Switch(
                  value: _mockHomeUrgent,
                  activeThumbColor: BrandTokens.highFg,
                  onChanged: (val) => setState(() => _mockHomeUrgent = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BrandTokens.space16),

        // Header nhận diện thương hiệu + địa điểm
        Row(
          children: [
            const IgnivoLogo.mark(size: 44),
            const SizedBox(width: BrandTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tòa nhà IGNIVO - Khu A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Cập nhật lúc 14:32 · Trực tiếp WebSocket',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: BrandTokens.space16),

        // Thẻ Sự cố khẩn cấp (nếu có sự cố)
        if (_mockHomeUrgent) ...[
          Container(
            padding: const EdgeInsets.all(BrandTokens.space16),
            decoration: BoxDecoration(
              color: isDark ? BrandTokens.darkCriticalBg : BrandTokens.criticalBg,
              borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
              border: Border.all(
                color: isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: BrandTokens.space8,
                  runSpacing: BrandTokens.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                      size: 24,
                    ),
                    Text(
                      'SỰ CỐ CẦN CHÚ Ý',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                      ),
                    ),
                    _buildBadge('CRITICAL', 'critical', isDark),
                  ],
                ),
                const SizedBox(height: BrandTokens.space8),
                Text(
                  'Khu vực Bếp phụ (Camera Cam-02) · Mức tin cậy: 94.2%',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: BrandTokens.space12),
                Wrap(
                  spacing: BrandTokens.space8,
                  runSpacing: BrandTokens.space8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _tabController.animateTo(3);
                      },
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      label: const Text('Xem chi tiết'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                        side: BorderSide(
                          color:
                              isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder,
                        ),
                      ),
                      onPressed: () {
                        setState(() => _mockIncidentAcked = true);
                      },
                      child: Text(_mockIncidentAcked ? 'Đã ACK' : 'Xác nhận (ACK)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: BrandTokens.space16),
        ],

        // Khả năng giám sát: Camera, AI, Kết nối
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            side: BorderSide(color: isDark ? BrandTokens.darkBorder : BrandTokens.border),
          ),
          color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
          child: Padding(
            padding: const EdgeInsets.all(BrandTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khả năng giám sát',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: BrandTokens.space12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.videocam_outlined,
                        title: 'Camera',
                        value: '2/2 Online',
                        color: isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.psychology_outlined,
                        title: 'Nhận diện AI',
                        value: 'Đang giám sát',
                        color: isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.wifi,
                        title: 'Kết nối Pi',
                        value: 'Ổn định',
                        color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BrandTokens.space20),

        // Camera xem nhanh (16:9 Thumbnail Cards)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Camera xem nhanh',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: BrandTokens.space8),
        Row(
          children: [
            Expanded(
              child: _buildMockCameraCard(
                title: 'Cam-01: Cổng chính',
                status: 'Trực tiếp · AI bật',
                isAlert: false,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: BrandTokens.space12),
            Expanded(
              child: _buildMockCameraCard(
                title: 'Cam-02: Bếp phụ',
                status: _mockHomeUrgent ? 'Cảnh báo lửa!' : 'Trực tiếp · AI bật',
                isAlert: _mockHomeUrgent,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: BrandTokens.space20),

        // Hoạt động gần đây
        Text(
          'Hoạt động gần đây',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
          ),
        ),
        const SizedBox(height: BrandTokens.space8),
        _buildActivityTile(
          title: 'Khởi động luồng suy luận AI Hailo-8L',
          time: '14:28:10',
          subtitle: 'Cam-01 và Cam-02 hoạt động ở mức 15 FPS',
          icon: Icons.check_circle_outline,
          isDark: isDark,
        ),
        _buildActivityTile(
          title: 'Kết nối WebSocket tới Edge Pi hoàn tất',
          time: '14:25:02',
          subtitle: 'Phiên giám sát mã hóa SHA-256',
          icon: Icons.link,
          isDark: isDark,
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: MÀN HÌNH CHI TIẾT SỰ CỐ MẪU (MOCK INCIDENT DETAIL)
  // ===========================================================================
  Widget _buildMockIncidentDetailScreen(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(BrandTokens.space16),
      children: [
        // Banner thông tin sự cố
        Container(
          padding: const EdgeInsets.all(BrandTokens.space16),
          decoration: BoxDecoration(
            color: isDark ? BrandTokens.darkCriticalBg : BrandTokens.criticalBg,
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            border: Border.all(
              color: isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: BrandTokens.space8,
                runSpacing: BrandTokens.space8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _buildBadge('SỰ CỐ KHẨN CẤP #INC-8941', 'critical', isDark),
                  _buildBadge(
                    _mockIncidentAcked ? 'ĐÃ XÁC NHẬN (ACK)' : 'CHƯA XÁC NHẬN',
                    _mockIncidentAcked ? 'acknowledged' : 'critical',
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: BrandTokens.space12),
              Text(
                'Phát hiện ngọn lửa bùng phát',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg,
                ),
              ),
              const SizedBox(height: BrandTokens.space4),
              Text(
                'Khu vực: Bếp phụ · Camera: Cam-02 · Thời gian: 14:31:05',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BrandTokens.space16),

        // Khung ảnh bằng chứng (16:9 AspectRatio)
        ClipRRect(
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          child: Container(
            height: 200,
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 48, color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(height: 8),
                      const Text(
                        'Ảnh chụp bằng chứng sự cố (Snapshot)',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LỬA: 94.2%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BrandTokens.space16),

        // Nhận định bổ sung AI
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            side: BorderSide(color: isDark ? BrandTokens.darkBorder : BrandTokens.border),
          ),
          color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
          child: Padding(
            padding: const EdgeInsets.all(BrandTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhận định phân tích AI Edge',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: BrandTokens.space8),
                Text(
                  '• Mô hình YOLOv8-Fire xác nhận đối tượng "fire" với độ tin cậy vượt ngưỡng kích hoạt 75%.\n'
                  '• Khung hình liên tiếp trong 3 giây đều ghi nhận vết nhiệt và vùng quang phát sáng.\n'
                  '• Đã gửi tín hiệu khẩn cấp đến hệ thống chuông báo động vật lý.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BrandTokens.space24),

        // Action Bar (Tách biệt rõ Tắt âm cục bộ và Xác nhận ACK)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: _mockIncidentAcked
                    ? (isDark ? BrandTokens.darkSurfaceVariant : Colors.grey.shade300)
                    : (isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg),
                foregroundColor: _mockIncidentAcked
                    ? (isDark ? BrandTokens.darkTextSecondary : Colors.black87)
                    : Colors.white,
              ),
              onPressed: () {
                setState(() => _mockIncidentAcked = !_mockIncidentAcked);
              },
              icon: Icon(_mockIncidentAcked ? Icons.check_circle : Icons.warning_amber_rounded),
              label: Text(
                _mockIncidentAcked
                    ? 'Đã xác nhận sự cố (Bấm để hủy ACK mẫu)'
                    : 'Xác nhận đã biết sự cố (ACK)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: BrandTokens.space12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: isDark ? BrandTokens.darkMediumFg : BrandTokens.mediumFg,
                side: BorderSide(
                  color: isDark ? BrandTokens.darkMediumBorder : BrandTokens.mediumBorder,
                ),
              ),
              onPressed: () {
                setState(() => _mockIncidentSilenced = !_mockIncidentSilenced);
              },
              icon: Icon(_mockIncidentSilenced ? Icons.volume_up : Icons.volume_off),
              label: Text(_mockIncidentSilenced ? 'Bật lại âm thanh' : 'Tắt âm còi cục bộ'),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SUB-WIDGET HELPERS
  // ===========================================================================
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildColorChip(String label, Color color, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
      ),
      child: Text(
        label,
        style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBadge(String label, String severity, bool isDark, {IconData? icon}) {
    final style = StatusStyle.forSeverity(severity, isDark: isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: style.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: style.foreground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMockCameraCard({
    required String title,
    required String status,
    required bool isAlert,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isAlert
              ? (isDark ? BrandTokens.darkCriticalBorder : BrandTokens.criticalBorder)
              : (isDark ? BrandTokens.darkBorder : BrandTokens.border),
          width: isAlert ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: const Center(
              child: Icon(Icons.videocam, color: Colors.white54, size: 36),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BrandTokens.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: isAlert
                        ? (isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg)
                        : (isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String time,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BrandTokens.brandPrimary),
          const SizedBox(width: BrandTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
