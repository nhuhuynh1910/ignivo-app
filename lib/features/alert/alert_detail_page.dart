import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert_model.dart';

class AlertDetailPage extends StatefulWidget {
  const AlertDetailPage({
    super.key,
    required this.alert,
  });

  final AlertModel alert;

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = false;

  Future<void> _acknowledge() async {
    setState(() {
      _loading = true;
    });

    try {
      await _firestoreService.acknowledgeAlert(
        systemId: widget.alert.systemId,
        alertId: widget.alert.id,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xác nhận cảnh báo.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Chi tiết sự cố & Cảnh báo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============================================================
          // SNAPSHOT EVIDENCE IMAGE
          // ============================================================
          if (alert.snapshotUrl.isNotEmpty) ...[
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  alert.snapshotUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Không thể tải hình ảnh bằng chứng',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.backgroundBlueSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _severityColor(alert.severity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _severityLabel(alert.severity),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _severityColor(alert.severity),
                        ),
                      ),
                    ),
                    if (alert.createdAt != null)
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm:ss').format(alert.createdAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const Divider(height: 28),

                _InfoRow(
                  title: 'Edge Box',
                  value: alert.systemName,
                ),

                _InfoRow(
                  title: 'Khu vực phát hiện',
                  value: alert.zoneName,
                ),

                _InfoRow(
                  title: 'Camera ghi nhận',
                  value: alert.cameraName,
                ),

                _InfoRow(
                  title: 'Loại sự kiện',
                  value: alert.type,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Tóm tắt sự cố (Incident Summary)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert.message.isEmpty ? 'Hệ thống AI local trên Raspberry Pi 5 phát hiện nguy cơ bất thường.' : alert.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (!alert.acknowledged)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _acknowledge,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _loading ? 'Đang xác nhận...' : 'Xác nhận đã xử lý sự cố',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.danger;
      case 'ALERT':
      case 'SUSPICIOUS':
        return AppColors.warning;
      case 'NORMAL':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _severityLabel(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return 'MỨC NGUY HIỂM';
      case 'ALERT':
        return 'MỨC CẢNH BÁO';
      case 'SUSPICIOUS':
        return 'MỨC BẤT THƯỜNG';
      case 'NORMAL':
        return 'BÌNH THƯỜNG';
      default:
        return severity;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
