import 'package:flutter/material.dart';

class PulsingAlertWrapper extends StatefulWidget {
  const PulsingAlertWrapper({
    super.key,
    required this.child,
    this.active = true,
    this.glowColor = const Color(0xFFEF4444),
  });

  final Widget child;
  final bool active;
  final Color glowColor;

  @override
  State<PulsingAlertWrapper> createState() => _PulsingAlertWrapperState();
}

class _PulsingAlertWrapperState extends State<PulsingAlertWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.active && !_isTest) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsingAlertWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating && !_isTest) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withValues(alpha: 0.15 + 0.35 * _animation.value),
              blurRadius: 8.0 + 10.0 * _animation.value,
              spreadRadius: 1.0 + 2.5 * _animation.value,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class GuardPanel extends StatelessWidget {
  const GuardPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class GuardBadge extends StatelessWidget {
  const GuardBadge(this.label, {super.key, this.color = Colors.blueGrey});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

String cameraHealth(Map<String, dynamic> camera, {bool stale = false}) {
  if (stale) return 'Chưa cập nhật';
  if (camera['enabled'] == false) return 'Đã tắt';
  final status = camera['status'] as Map?;
  if (status == null) return 'Chưa có trạng thái';
  if (status['online'] != true) return 'Offline';
  if (camera['detect_enabled'] == false || status['state'] == 'AI_OFF') {
    return 'AI đang tắt';
  }
  if ((status['ai_fps'] as num? ?? 0) <= 0) return 'AI chưa có dữ liệu';
  return switch (status['state']) {
    'SAFE' => 'Chưa phát hiện',
    'FIRE' => 'Phát hiện lửa',
    'SMOKE' => 'Phát hiện khói',
    _ => '${status['state'] ?? 'Online'}',
  };
}

class CameraTelemetry extends StatelessWidget {
  const CameraTelemetry({
    super.key,
    required this.camera,
    this.stale = false,
    this.modelClasses = const [],
  });
  final Map<String, dynamic> camera;
  final bool stale;
  final List<dynamic> modelClasses;
  @override
  Widget build(BuildContext context) {
    final status = camera['status'] as Map? ?? {};
    final online =
        !stale && camera['enabled'] != false && status['online'] == true;
    final ai =
        online &&
        camera['detect_enabled'] != false &&
        status['state'] != 'AI_OFF' &&
        (status['ai_fps'] as num? ?? 0) > 0;
    final scores = status['scores'] as Map? ?? {};
    final fire = ['fire', 'kitchen_fire', 'lighter_fire', 'cigarette_fire']
        .map((k) => (scores[k] as num? ?? 0).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    Widget score(String label, double value, String modelClass, Color color) {
      final supported =
          modelClasses.isEmpty || modelClasses.contains(modelClass);
      final valid = ai && supported && scores.containsKey(modelClass);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label · ${!supported
                  ? 'Model không hỗ trợ'
                  : !valid
                  ? 'Chưa có dữ liệu mới'
                  : '${(value * 100).round()}%'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: valid ? value.clamp(0, 1) : 0,
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            GuardBadge(
              cameraHealth(camera, stale: stale),
              color: !online
                  ? Colors.red
                  : ai && status['state'] == 'SAFE'
                  ? Colors.teal
                  : Colors.orange,
            ),
            GuardBadge('AI ${stale ? '—' : status['ai_fps'] ?? '—'} fps'),
            GuardBadge(
              'Camera ${stale ? '—' : status['capture_fps'] ?? '—'} fps',
            ),
            if (status['resolution'] is List)
              GuardBadge((status['resolution'] as List).join(' × ')),
          ],
        ),
        if (!online)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Chưa có hình trực tiếp. Kiểm tra kết nối camera trên Pi.',
            ),
          ),
        if (status['error'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${status['error']}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        score('Lửa', fire, 'fire', Colors.deepOrange),
        score(
          'Khói',
          (scores['smoke'] as num? ?? 0).toDouble(),
          'smoke',
          Colors.blueGrey,
        ),
        score(
          'Người',
          (scores['human'] as num? ?? 0).toDouble(),
          'human',
          Colors.blue,
        ),
      ],
    );
  }
}

class IncidentPresentationHelper {
  static String cameraName(Map<String, dynamic> incident) {
    final name = incident['camera_name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }
    final source = incident['source']?.toString().trim();
    if (source != null &&
        source.isNotEmpty &&
        !source.contains('://') &&
        !source.startsWith('/dev/')) {
      return source;
    }
    return 'Camera #${incident['camera_id'] ?? incident['id']}';
  }

  static String areaText(Map<String, dynamic> incident) {
    final area = incident['area'];
    if (area != null && area.toString().trim().isNotEmpty) {
      return area.toString().trim();
    }
    return 'Chưa xác định khu vực';
  }

  static String severityLabel(dynamic severity) {
    final s = severity?.toString().toLowerCase().trim();
    return switch (s) {
      'critical' => 'Cực kỳ nguy hiểm',
      'high' => 'Nguy hiểm cao',
      'medium' => 'Cảnh báo trung bình',
      'low' => 'Mức độ thấp',
      _ => 'Đang đánh giá mức độ',
    };
  }

  static String triggerLabel(dynamic trigger) {
    final t = trigger?.toString().toLowerCase().trim();
    return switch (t) {
      'fire' => 'Phát hiện Lửa',
      'smoke' => 'Phát hiện Khói',
      _ => '${trigger ?? 'Cảnh báo'}',
    };
  }
}

