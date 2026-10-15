import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../settings/edge_connection_page.dart';

class SystemDetailPage extends StatefulWidget {
  const SystemDetailPage({super.key});

  @override
  State<SystemDetailPage> createState() => _SystemDetailPageState();
}

class _SystemDetailPageState extends State<SystemDetailPage> {
  final FireguardApiService _api = FireguardApiService.instance;

  bool _loading = true;
  bool _connected = false;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _loading = true);
    final isOk = await _api.checkConnection();
    Map<String, dynamic>? status;
    if (isOk) {
      status = await _api.getSystemStatus();
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _connected = isOk && status != null;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Chi tiết thiết bị Edge Box',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EdgeConnectionPage()),
              );
              _fetchStatus();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // STATUS CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.backgroundBlueSoft),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _connected ? AppColors.success.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _connected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                          color: _connected ? AppColors.success : AppColors.danger,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _connected ? 'Edge Box Đang Trực Tuyến' : 'Edge Box Đang Ngoại Tuyến',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _connected ? AppColors.success : AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _api.baseUrl,
                              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EdgeConnectionPage()),
                          );
                          _fetchStatus();
                        },
                        child: const Text('Đổi IP', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                if (_status != null) ...[
                  // HARDWARE METRICS
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.backgroundBlueSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TÀI NGUYÊN PHẦN CỨNG',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                        ),
                        const Divider(height: 20),
                        _InfoItem(
                          icon: Icons.computer_rounded,
                          title: 'Thiết bị & Model',
                          value: '${_status!['model'] ?? _status!['hostname'] ?? "Raspberry Pi 5"}',
                        ),
                        _InfoItem(
                          icon: Icons.thermostat_rounded,
                          title: 'Nhiệt độ CPU',
                          value: '${_status!['cpu_temp_c'] ?? "Chưa rõ"}°C',
                        ),
                        _InfoItem(
                          icon: Icons.speed_rounded,
                          title: 'Tải hệ thống (Load Avg)',
                          value: '${_status!['load_avg'] is List ? (_status!['load_avg'] as List).join(", ") : (_status!['load_avg'] ?? "Chưa rõ")}',
                        ),
                        _InfoItem(
                          icon: Icons.access_time_rounded,
                          title: 'Thời gian hoạt động',
                          value: '${_status!['uptime_s'] != null ? (_status!['uptime_s'] / 3600).toStringAsFixed(1) : "0"} giờ',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // AI & VISION ENGINE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.backgroundBlueSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BỘ XỬ LÝ TRÍ TUỆ NHÂN TẠO (AI)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                        ),
                        const Divider(height: 20),
                        _InfoItem(
                          icon: Icons.bolt_rounded,
                          title: 'Chip tăng tốc AI',
                          value: (_status!['hailo_ready'] == true) ? 'Hailo-8L NPU (Hoạt động)' : 'Không phát hiện chip',
                          color: (_status!['hailo_ready'] == true) ? AppColors.success : AppColors.danger,
                        ),
                        _InfoItem(
                          icon: Icons.smart_toy_rounded,
                          title: 'Nguồn phát hiện cháy',
                          value: (_status!['detection_source'] == 'local') ? 'Camera cục bộ (Hailo Vision Engine)' : 'FireEye IP Camera (MQTT)',
                        ),
                        _InfoItem(
                          icon: Icons.call_rounded,
                          title: 'Nhà cung cấp cuộc gọi',
                          value: '${_status!['call_provider'] ?? "Stringee"} Callout REST API',
                        ),
                        _InfoItem(
                          icon: Icons.psychology_rounded,
                          title: 'Mô hình phân tích hiện trường',
                          value: '${_status!['gemini_model'] ?? "gemini-2.5-flash"}',
                        ),
                      ],
                    ),
                  ),
                ] else if (!_connected) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          const Text(
                            'Chưa kết nối được với Edge Box',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Vui lòng cấu hình đúng địa chỉ IP của Raspberry Pi 5 và đảm bảo service FireGuard đang chạy trên cổng 8080.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EdgeConnectionPage()),
                            ),
                            icon: const Icon(Icons.settings),
                            label: const Text('Cấu hình kết nối'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.title,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
