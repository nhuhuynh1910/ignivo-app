import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/fireguard_realtime_service.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../fireguard/monitoring_controller.dart';
import 'brand_showcase_page.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({
    super.key,
    required this.monitoringController,
    required this.sessionController,
  });

  final MonitoringController monitoringController;
  final SystemSessionController sessionController;

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Chưa có thông tin';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s (${dt.day}/${dt.month}/${dt.year})';
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'Chưa xác thực';
    if (token.length <= 10) return '••••••••';
    return '${token.substring(0, 6)}••••••••${token.substring(token.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chẩn đoán hệ thống'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới chẩn đoán',
            onPressed: monitoringController.refresh,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: monitoringController,
        builder: (context, _) {
          final status = monitoringController.status ?? {};
          final isStale = monitoringController.stale;
          final realtimeState = monitoringController.realtime.state;
          final isWsConnected = realtimeState == FireguardConnection.connected;
          final vision = status['vision'] as Map? ?? {};
          final isHailoReady = vision['ready'] == true || status['hailo_ready'] == true;
          final totalAiFps = (vision['total_ai_fps'] ?? status['total_ai_fps'] ?? 0).toString();
          final stringeeConfigured = status['stringee_configured'] == true;
          final familyCount = status['family_contacts'] ?? 0;
          final fireDeptCount = status['fire_dept_contacts'] ?? 0;
          final hostname = status['hostname']?.toString() ?? 'ignivo-edge';
          final deviceId = sessionController.deviceId ?? status['device_id']?.toString() ?? 'Chưa cấu hình';
          final token = sessionController.api.authToken;

          final normalColor = isDark ? BrandTokens.darkNormalFg : BrandTokens.normalFg;
          final normalBorder = isDark ? BrandTokens.darkNormalBorder : BrandTokens.normalBorder;
          final mediumColor = isDark ? BrandTokens.darkMediumFg : BrandTokens.mediumFg;
          final mediumBorder = isDark ? BrandTokens.darkMediumBorder : BrandTokens.mediumBorder;
          final criticalColor = isDark ? BrandTokens.darkCriticalFg : BrandTokens.criticalFg;
          final defaultBorder = isDark ? BrandTokens.darkBorder : BrandTokens.border;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // System Health Summary Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  side: BorderSide(
                    color: isWsConnected && !isStale ? normalBorder : mediumBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isWsConnected ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: isWsConnected ? normalColor : mediumColor,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isWsConnected
                                  ? 'Cảnh báo trực tiếp: Sẵn sàng'
                                  : 'Cảnh báo trực tiếp: Đang kết nối lại',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        monitoringController.connectionLabel,
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                      ),
                      const Divider(height: 20),
                      _buildMetricRow(
                        context,
                        'Trạng thái dữ liệu',
                        isStale ? 'Cần đồng bộ lại' : 'Mới nhất',
                        valueColor: isStale ? mediumColor : normalColor,
                      ),
                      const SizedBox(height: 6),
                      _buildMetricRow(context, 'Cập nhật lần cuối', _formatTime(monitoringController.updated)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Edge Box Hardware & Vision NPU
              _buildSectionHeader(context, 'Bộ xử lý biên & NPU Hailo'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  side: BorderSide(color: defaultBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricRow(context, 'Tên máy chủ Pi', hostname),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Mã thiết bị (Device ID)', deviceId),
                      const SizedBox(height: 10),
                      _buildMetricRow(
                        context,
                        'Hailo-8 / NPU AI',
                        isHailoReady ? 'Sẵn sàng' : 'Chưa sẵn sàng',
                        valueColor: isHailoReady ? normalColor : criticalColor,
                      ),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Tổng AI FPS', '$totalAiFps FPS'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Voice Call Service (Stringee)
              _buildSectionHeader(context, 'Hệ thống gọi khẩn cấp (Stringee)'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  side: BorderSide(color: defaultBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricRow(
                        context,
                        'Cấu hình tổng đài',
                        stringeeConfigured ? 'Đã thiết lập' : 'Chưa thiết lập',
                        valueColor: stringeeConfigured ? normalColor : mediumColor,
                      ),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Số liên hệ người thân', '$familyCount người'),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Số liên hệ PCCC', '$fireDeptCount cơ quan'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Network & Security
              _buildSectionHeader(context, 'Mạng và Bảo mật phiên'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                  side: BorderSide(color: defaultBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricRow(context, 'Địa chỉ FireGuard Edge', sessionController.guardUrl),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Vai trò tài khoản', sessionController.role ?? 'USER'),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Mã phiên (RAM masked)', _maskToken(token)),
                      const SizedBox(height: 10),
                      _buildMetricRow(context, 'Chính sách lưu phiên', 'RAM bộ nhớ tạm (Không lưu đĩa)'),
                    ],
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Thiết kế & Giao diện (Debug Only)'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('IGNIVO Brand Showcase'),
                    subtitle: const Text('Thư viện linh kiện & 3 màn hình mẫu (Light/Dark/200% Font)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BrandShowcasePage()),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
