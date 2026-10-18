import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

/// Thẻ tổng quan trạng thái IGNIVO Edge Box theo phong cách Stitch
///
/// Thể hiện kết nối Edge Box, nhận diện AI cục bộ (Hailo NPU), trạng thái
/// cảnh báo trực tiếp qua WebSocket và số camera đồng bộ.
class EdgeStatusCard extends StatelessWidget {
  const EdgeStatusCard({
    super.key,
    required this.systemName,
    this.isOnline = true,
    this.isStale = false,
    this.aiModel = 'Hailo-8L',
    this.aiActive = true,
    this.directAlertConnected = true,
    this.directAlertStatus = 'Kết nối',
    this.totalCameras = 0,
    this.onlineCameras = 0,
    this.unknownCameras = 0,
    this.onTap,
  });

  final String systemName;
  final bool isOnline;
  final bool isStale;
  final String? aiModel;
  final bool aiActive;
  final bool directAlertConnected;
  final String directAlertStatus;
  final int totalCameras;
  final int onlineCameras;
  final int unknownCameras;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? [const Color(0xFF0F2B5C), const Color(0xFF0A1C3E)]
        : [BrandTokens.brandPrimary, const Color(0xFF004F98)];

    final borderColor = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.18);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : const Color(0xFF005CAF).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(BrandTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: Tên hệ thống + Badge an toàn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.roofing_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Hệ thống: $systemName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSafeBadge(isStale),
                  ],
                ),
                const SizedBox(height: 16),

                // 4 ô thông tin telemetry: phản hồi theo kích thước màn hình
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    if (isNarrow) {
                      return _build2x2Grid(context);
                    }
                    return _build4ColRow(context);
                  },
                ),
                const SizedBox(height: 14),

                // Dòng ghi chú chân thẻ
                // Row(
                //   children: [
                //     Icon(
                //       Icons.memory_rounded,
                //       size: 15,
                //       color: Colors.white.withValues(alpha: 0.85),
                //     ),
                //     const SizedBox(width: 6),
                //     Expanded(
                //       child: Text(
                //         isStale
                //             ? 'Dữ liệu Edge Box cần làm mới • Đang kết nối lại'
                //             : 'Quản lý cục bộ bởi IGNIVO Edge Box • Hoạt động ổn định',
                //         style: TextStyle(
                //           fontSize: 12,
                //           color: Colors.white.withValues(alpha: 0.85),
                //           fontWeight: FontWeight.w400,
                //         ),
                //         overflow: TextOverflow.ellipsis,
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeBadge(bool stale) {
    if (stale) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: Colors.amber.shade300, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.amber.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Cần đồng bộ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrandTokens.stitchSafe.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: BrandTokens.stitchSafe.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: BrandTokens.stitchSafe,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Chưa ghi nhận sự cố',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build4ColRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              label: 'Edge Box',
              valueWidget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? BrandTokens.stitchSafe
                          : BrandTokens.stitchCritical,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildMetricTile(
              label: 'Local AI',
              valueWidget: Text(
                aiModel ?? (aiActive ? 'Bật' : 'Tắt'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildMetricTile(
              label: 'Cảnh báo trực tiếp',
              valueWidget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    directAlertConnected ? Icons.wifi : Icons.wifi_off,
                    size: 13,
                    color: directAlertConnected
                        ? BrandTokens.stitchSafe
                        : BrandTokens.stitchWarning,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      directAlertStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildMetricTile(
              label: 'Camera',
              valueWidget: Text(
                '$onlineCameras/$totalCameras',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build2x2Grid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Edge Box',
                  valueWidget: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline
                          ? BrandTokens.stitchSafe
                          : BrandTokens.stitchCritical,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _buildMetricTile(
                  label: 'Local AI',
                  valueWidget: Text(
                    aiModel ?? (aiActive ? 'Bật' : 'Tắt'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Cảnh báo trực tiếp',
                  valueWidget: Text(
                    directAlertStatus,
                    style: TextStyle(
                      color: directAlertConnected
                          ? BrandTokens.stitchSafe
                          : BrandTokens.stitchWarning,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _buildMetricTile(
                  label: 'Camera',
                  valueWidget: Text(
                    '$onlineCameras/$totalCameras đồng bộ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required Widget valueWidget,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        valueWidget,
      ],
    );
  }
}
