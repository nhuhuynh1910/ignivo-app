import 'package:flutter/material.dart';

import 'alert_detail_page.dart';


class AlertPage extends StatelessWidget {
  const AlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cảnh báo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),


      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // TỔNG QUAN CẢNH BÁO
          // =========================

          Container(
            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.shade100,
              ),
            ),

            child: Row(
              children: [
                Icon(
                  Icons.shield,
                  size: 42,
                  color: Colors.green.shade700,
                ),

                const SizedBox(width: 16),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hệ thống an toàn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Không có cảnh báo nghiêm trọng',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // =========================
          // CẢNH BÁO HIỆN TẠI
          // =========================

          const Text(
            'Cảnh báo hiện tại',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _alertCard(
            context: context,
            severity: 'LOW',
            title: 'Nhiệt độ tăng',
            description:
            'Nhiệt độ tại khu vực bếp đang cao hơn mức thông thường.',
            zone: 'Khu vực bếp',
            time: 'Vừa xong',
            icon: Icons.thermostat,
          ),

          const SizedBox(height: 12),

          _alertCard(
            context: context,
            severity: 'MEDIUM',
            title: 'Phát hiện khói',
            description:
            'Camera AI phát hiện dấu hiệu khói trong khu vực.',
            zone: 'Phòng khách',
            time: '5 phút trước',
            icon: Icons.cloud,
          ),

          const SizedBox(height: 12),

          _alertCard(
            context: context,
            severity: 'HIGH',
            title: 'Nguy cơ cháy',
            description:
            'Hệ thống phát hiện đồng thời nhiều dấu hiệu bất thường.',
            zone: 'Khu vực bếp',
            time: '10 phút trước',
            icon: Icons.local_fire_department,
          ),

          const SizedBox(height: 24),

          // =========================
          // SỰ KIỆN GẦN ĐÂY
          // =========================

          const Text(
            'Sự kiện gần đây',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _eventItem(
            icon: Icons.check_circle,
            title: 'Kiểm tra hệ thống',
            description: 'Hệ thống hoạt động bình thường',
            time: 'Hôm nay, 08:30',
          ),

          _eventItem(
            icon: Icons.videocam,
            title: 'Camera hoạt động',
            description: 'Camera phòng khách đã kết nối',
            time: 'Hôm nay, 08:15',
          ),

          _eventItem(
            icon: Icons.sensors,
            title: 'Cảm biến cập nhật',
            description: 'Dữ liệu cảm biến đã được đồng bộ',
            time: 'Hôm nay, 08:00',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD CẢNH BÁO
  // ============================================================

  Widget _alertCard({
    required BuildContext context,
    required String severity,
    required String title,
    required String description,
    required String zone,
    required String time,
    required IconData icon,
  }) {
    final Color color;
    final Color backgroundColor;

    switch (severity) {
      case 'HIGH':
        color = Colors.red;
        backgroundColor = Colors.red.shade50;
        break;

      case 'MEDIUM':
        color = Colors.orange;
        backgroundColor = Colors.orange.shade50;
        break;

      default:
        color = Colors.blue;
        backgroundColor = Colors.blue.shade50;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),


      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),

        child: Row(
          children: [
            // Icon cảnh báo
            Container(
              width: 50,
              height: 50,

              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),

              child: Icon(
                icon,
                color: color,
                size: 27,
              ),
            ),

            const SizedBox(width: 14),

            // Nội dung
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      _severityBadge(
                        severity,
                        color,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.grey.shade600,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        zone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Icon(
                        Icons.access_time,
                        size: 15,
                        color: Colors.grey.shade600,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BADGE MỨC ĐỘ
  // ============================================================

  Widget _severityBadge(
      String severity,
      Color color,
      ) {
    String text;

    switch (severity) {
      case 'HIGH':
        text = 'CAO';
        break;

      case 'MEDIUM':
        text = 'TRUNG BÌNH';
        break;

      default:
        text = 'THẤP';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // EVENT ITEM
  // ============================================================

  Widget _eventItem({
    required IconData icon,
    required String title,
    required String description,
    required String time,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 4,
      ),

      leading: CircleAvatar(
        child: Icon(icon),
      ),

      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),

      subtitle: Text(
        '$description\n$time',
      ),

      isThreeLine: true,
    );
  }
}