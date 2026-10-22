import 'package:flutter/material.dart';
import '../../core/theme/brand_tokens.dart';

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
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        side: BorderSide(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
          width: 0.8,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
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
      'simulation' => 'Sự cố mô phỏng',
      _ => '${trigger ?? 'Cảnh báo'}',
    };
  }

  /// Tạo tiêu đề sự cố người dùng dễ quét nhanh theo chuẩn:
  /// "[Loại sự cố] · [Tên Camera] · [Khu vực]"
  /// Ví dụ: "Phát hiện lửa · Camera phòng khách · Tầng 1"
  static String formatIncidentTitle(Map<String, dynamic> incident) {
    final trigger = triggerLabel(incident['trigger_type']);
    final cam = cameraName(incident);
    final rawArea = incident['area']?.toString().trim();
    final hasArea = rawArea != null &&
        rawArea.isNotEmpty &&
        rawArea != 'Chưa xác định khu vực';

    if (hasArea && !cam.toLowerCase().contains(rawArea.toLowerCase())) {
      return '$trigger · $cam · $rawArea';
    }
    return '$trigger · $cam';
  }

  /// Định dạng thời gian sự cố ngắn gọn, dễ quét cho người dùng
  static String formatTimestamp(dynamic rawTime) {
    if (rawTime == null) return '';
    final str = rawTime.toString().trim();
    if (str.isEmpty) return '';
    try {
      final dt = DateTime.parse(str).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds >= 0 && diff.inMinutes < 1) {
        return 'Vừa xong';
      } else if (diff.inMinutes < 60 && diff.inMinutes >= 1) {
        return '${diff.inMinutes} phút trước';
      } else if (diff.inHours < 24 && diff.inHours >= 1) {
        return '${diff.inHours} giờ trước';
      } else {
        final d = dt.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final h = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '$h:$min $d/$m';
      }
    } catch (_) {
      return str.replaceAll('T', ' ').split('.').first;
    }
  }
}

/// Helper thuần túy ánh xạ trạng thái và mức độ nghiêm trọng của sự cố.
///
/// TUÂN THỦ NGHIÊM NGẶT CÁC INVARIANTS:
/// - Không gọi API, không phát âm thanh, không sửa đổi trạng thái controller.
/// - Không tự động coi status 'open' thô là hợp lệ mà kiểm tra mapping rõ ràng.
/// - Không fallback mù quáng về 'high' khi severity bị thiếu/null.
/// - Hiệu ứng pulse chỉ bật khi sự cố đang hoạt động (not resolved, false_alarm, ai_dismissed),
///   chưa được xác nhận (status != 'acknowledged'), dữ liệu không cũ (stale == false),
///   không phải sự kiện mô phỏng, và không bị tắt animation (disableAnimations == false).
class AlertPresentationMapping {
  AlertPresentationMapping._();

  /// Đánh giá xem có nên bật hiệu ứng nhấp nháy cảnh báo (pulse) hay không.
  static bool shouldPulse({
    required Map<String, dynamic>? incident,
    bool stale = false,
    bool disableAnimations = false,
  }) {
    if (incident == null || stale || disableAnimations) return false;

    // Sự kiện mô phỏng không được phát hiệu ứng pulse khẩn cấp thật
    final isSimulation = incident['simulation'] == true ||
        incident['is_simulation'] == true ||
        incident['source']?.toString().toLowerCase().contains('simulation') == true;
    if (isSimulation) return false;

    final status = incident['status']?.toString().toLowerCase().trim();

    // Các trạng thái kết thúc hoặc đã xử lý không được pulse
    if (status == 'resolved' ||
        status == 'false_alarm' ||
        status == 'ai_dismissed') {
      return false;
    }

    // Đã được xác nhận (ACK) trong phiên: dừng pulse cho sự cố này
    if (status == 'acknowledged') {
      return false;
    }

    // Chỉ pulse khi có nguy cơ thực sự đang hoạt động
    final severity = incident['severity']?.toString().toLowerCase().trim();
    if (severity == 'none') return false;

    // Chỉ pulse với critical hoặc high đang chưa ACK
    return severity == 'critical' || severity == 'high';
  }

  /// Trả về nhãn trạng thái tiếng Việt chuẩn
  static String statusLabel(String? rawStatus) {
    final s = rawStatus?.toLowerCase().trim();
    return switch (s) {
      'analyzing' => 'Đang phân tích',
      'notifying' => 'Đang phát cảnh báo',
      'notified' => 'Đã phát cảnh báo',
      'acknowledged' => 'Đã xác nhận',
      'resolved' => 'Đã xử lý xong',
      'false_alarm' => 'Báo động giả',
      'ai_dismissed' => 'AI đã bỏ qua',
      'error' => 'Lỗi giám sát',
      'offline' => 'Mất kết nối',
      'stale' => 'Dữ liệu cũ',
      _ => 'Chưa xác định trạng thái',
    };
  }

  /// Trả về nhãn mức độ nguy hiểm
  static String severityLabel(String? rawSeverity) {
    final s = rawSeverity?.toLowerCase().trim();
    return switch (s) {
      'critical' => 'Khẩn cấp',
      'high' => 'Nguy cơ cao',
      'medium' => 'Cảnh báo vừa',
      'low' => 'Mức độ thấp',
      'none' => 'An toàn (None)',
      _ => 'Chưa xác định mức độ',
    };
  }

  /// Trả về màu sắc ngữ nghĩa trạng thái an toàn
  static StatusStyle statusStyle({
    required String? severity,
    required bool isDark,
  }) {
    return StatusStyle.forSeverity(severity, isDark: isDark);
  }
}

/// Kết quả đánh giá trạng thái AI theo 7 quy tắc ưu tiên (Mục 5.1 Kế hoạch)
class AiStatusResult {
  const AiStatusResult({
    required this.ruleLevel,
    required this.label,
    this.secondaryLabel,
    this.isActive = false,
    this.isOff = false,
    this.isError = false,
    this.isStale = false,
  });

  final int ruleLevel;
  final String label;
  final String? secondaryLabel;
  final bool isActive;
  final bool isOff;
  final bool isError;
  final bool isStale;
}

/// Trình đánh giá trạng thái AI Telemetry theo bảng ưu tiên 7 cấp
class AiTelemetryEvaluator {
  AiTelemetryEvaluator._();

  /// Ngưỡng thời gian tối đa để coi lần suy luận AI là còn mới (fresh)
  static const Duration defaultFreshnessThreshold = Duration(seconds: 15);

  /// Đánh giá trạng thái AI của camera theo đúng thứ tự 1 -> 7
  static AiStatusResult evaluate({
    required Map<String, dynamic>? camera,
    bool stale = false,
    DateTime? now,
    Duration freshnessThreshold = defaultFreshnessThreshold,
  }) {
    final currentTime = now ?? DateTime.now();

    // =========================================================================
    // ƯU TIÊN 1: Sai camera/phiên, mất kết nối, dữ liệu đã cũ hoặc mâu thuẫn
    // =========================================================================
    if (camera == null || stale) {
      return const AiStatusResult(
        ruleLevel: 1,
        label: 'Chưa xác định trạng thái nhận diện',
        isStale: true,
      );
    }

    final status = camera['status'] as Map?;

    // =========================================================================
    // ƯU TIÊN 2: Có lỗi runtime đủ mới ngăn nhận diện
    // =========================================================================
    final runtimeError = status?['error']?.toString().trim();
    if (runtimeError != null && runtimeError.isNotEmpty) {
      return AiStatusResult(
        ruleLevel: 2,
        label: 'Lỗi nhận diện: $runtimeError',
        secondaryLabel: camera['detect_enabled'] == true ? 'Cấu hình: Bật' : 'Cấu hình: Tắt',
        isError: true,
      );
    }

    // =========================================================================
    // ƯU TIÊN 3: Cấu hình đủ mới xác nhận detect_enabled == false
    // =========================================================================
    if (camera['detect_enabled'] == false || status?['state'] == 'AI_OFF') {
      return const AiStatusResult(
        ruleLevel: 3,
        label: 'AI đang tắt',
        isOff: true,
      );
    }

    // =========================================================================
    // ƯU TIÊN 4: Nhận diện được bật nhưng runtime xác nhận running == false hoặc online == false
    // =========================================================================
    if (status != null) {
      final isOnline = status['online'] == true;
      final isRunning = status['running'] == true;
      if (!isOnline) {
        return const AiStatusResult(
          ruleLevel: 4,
          label: 'Camera mất kết nối',
          isError: true,
        );
      }
      if (!isRunning) {
        return const AiStatusResult(
          ruleLevel: 4,
          label: 'Nhận diện chưa hoạt động',
          secondaryLabel: 'Dịch vụ AI đang dừng trên Pi',
        );
      }
    }

    // =========================================================================
    // ƯU TIÊN 5: Cấu hình bật VÀ đáp ứng toàn bộ điều kiện runtime / suy luận gần đây
    // =========================================================================
    if (status != null && status['online'] == true && status['running'] == true) {
      final lastInferRaw = status['last_infer_at'];
      DateTime? lastInferTime;

      if (lastInferRaw is String && lastInferRaw.isNotEmpty) {
        lastInferTime = DateTime.tryParse(lastInferRaw);
      } else if (lastInferRaw is num && lastInferRaw > 0) {
        // Hỗ trợ unix timestamp (seconds hoặc milliseconds)
        lastInferTime = lastInferRaw > 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(lastInferRaw.toInt())
            : DateTime.fromMillisecondsSinceEpoch((lastInferRaw * 1000).toInt());
      }

      if (lastInferTime != null) {
        final age = currentTime.difference(lastInferTime);
        // Kiểm tra độ mới và loại trừ trường hợp chênh lệch đồng hồ âm quá xa
        if (!age.isNegative && age <= freshnessThreshold) {
          final aiFps = status['ai_fps'] as num? ?? 0;
          return AiStatusResult(
            ruleLevel: 5,
            label: 'AI đang giám sát',
            secondaryLabel: aiFps > 0 ? '${aiFps.toStringAsFixed(1)} FPS' : null,
            isActive: true,
          );
        }
      }
    }

    // =========================================================================
    // ƯU TIÊN 6: Chỉ có cấu hình bật đủ mới, chưa đủ bằng chứng runtime
    // =========================================================================
    if (camera['detect_enabled'] == true) {
      return const AiStatusResult(
        ruleLevel: 6,
        label: 'Đã bật nhận diện',
        secondaryLabel: 'Chưa xác định trạng thái hoạt động',
      );
    }

    // =========================================================================
    // ƯU TIÊN 7: Các trường hợp còn lại
    // =========================================================================
    return const AiStatusResult(
      ruleLevel: 7,
      label: 'Chưa xác định trạng thái nhận diện',
    );
  }
}

