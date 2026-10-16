import 'package:flutter/material.dart';
import '../../core/services/fireguard_realtime_service.dart';
import '../../core/services/system_session_controller.dart';
import '../fireguard/monitoring_controller.dart';

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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // System Health Summary Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isWsConnected && !isStale
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.amber.withValues(alpha: 0.4),
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
                            color: isWsConnected ? Colors.green : Colors.amber.shade700,
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
                      _buildMetricRow('Trạng thái dữ liệu', isStale ? 'Cần đồng bộ lại' : 'Mới nhất',
                          valueColor: isStale ? Colors.amber.shade800 : Colors.green),
                      const SizedBox(height: 6),
                      _buildMetricRow('Cập nhật lần cuối', _formatTime(monitoringController.updated)),
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
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricRow('Tên máy chủ Pi', hostname),
                      const SizedBox(height: 10),
                      _buildMetricRow('Mã thiết bị (Device ID)', deviceId),
                      const SizedBox(height: 10),
                      _buildMetricRow(
                        'Hailo-8 / NPU AI',
                        isHailoReady ? 'Sẵn sàng' : 'Chưa sẵn sàng',
                        valueColor: isHailoReady ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 10),
                      _buildMetricRow('Tổng AI FPS', '$totalAiFps FPS'),
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
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricRow(
                        'Cấu hình tổng đài',
                        stringeeConfigured ? 'Đã thiết lập' : 'Chưa thiết lập',
                        valueColor: stringeeConfigured ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 10),
                      _buildMetricRow('Số liên hệ người thân', '$familyCount người'),
                      const SizedBox(height: 10),
                      _buildMetricRow('Số liên hệ PCCC', '$fireDeptCount cơ quan'),
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
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricRow('Địa chỉ FireGuard Edge', sessionController.guardUrl),
                      const SizedBox(height: 10),
                      _buildMetricRow('Vai trò tài khoản', sessionController.role ?? 'USER'),
                      const SizedBox(height: 10),
                      _buildMetricRow('Mã phiên (RAM masked)', _maskToken(token)),
                      const SizedBox(height: 10),
                      _buildMetricRow('Chính sách lưu phiên', 'RAM bộ nhớ tạm (Không lưu đĩa)'),
                    ],
                  ),
                ),
              ),
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

  Widget _buildMetricRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
