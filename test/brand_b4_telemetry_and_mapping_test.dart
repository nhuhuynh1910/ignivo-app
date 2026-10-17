import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/features/fireguard/monitor_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gói B4: AlertPresentationMapping Unit Tests', () {
    test('statusLabel maps all known statuses and handles unknown/null', () {
      expect(AlertPresentationMapping.statusLabel('analyzing'), 'Đang phân tích');
      expect(AlertPresentationMapping.statusLabel('notifying'), 'Đang phát cảnh báo');
      expect(AlertPresentationMapping.statusLabel('notified'), 'Đã phát cảnh báo');
      expect(AlertPresentationMapping.statusLabel('acknowledged'), 'Đã xác nhận');
      expect(AlertPresentationMapping.statusLabel('resolved'), 'Đã xử lý xong');
      expect(AlertPresentationMapping.statusLabel('false_alarm'), 'Báo động giả');
      expect(AlertPresentationMapping.statusLabel('ai_dismissed'), 'AI đã bỏ qua');
      expect(AlertPresentationMapping.statusLabel('error'), 'Lỗi giám sát');
      expect(AlertPresentationMapping.statusLabel('offline'), 'Mất kết nối');
      expect(AlertPresentationMapping.statusLabel('stale'), 'Dữ liệu cũ');
      expect(AlertPresentationMapping.statusLabel('open'), 'Chưa xác định trạng thái');
      expect(AlertPresentationMapping.statusLabel(null), 'Chưa xác định trạng thái');
    });

    test('severityLabel maps severities and handles none/null', () {
      expect(AlertPresentationMapping.severityLabel('critical'), 'Khẩn cấp');
      expect(AlertPresentationMapping.severityLabel('high'), 'Nguy cơ cao');
      expect(AlertPresentationMapping.severityLabel('medium'), 'Cảnh báo vừa');
      expect(AlertPresentationMapping.severityLabel('low'), 'Mức độ thấp');
      expect(AlertPresentationMapping.severityLabel('none'), 'An toàn (None)');
      expect(AlertPresentationMapping.severityLabel(null), 'Chưa xác định mức độ');
    });

    test('shouldPulse enforces all safety criteria correctly', () {
      final activeCritical = {
        'id': 1,
        'status': 'notifying',
        'severity': 'critical',
      };

      // Active critical incident must pulse
      expect(
        AlertPresentationMapping.shouldPulse(incident: activeCritical, stale: false),
        isTrue,
      );

      // Stale data stops pulse
      expect(
        AlertPresentationMapping.shouldPulse(incident: activeCritical, stale: true),
        isFalse,
      );

      // Reduced motion stops pulse
      expect(
        AlertPresentationMapping.shouldPulse(
          incident: activeCritical,
          stale: false,
          disableAnimations: true,
        ),
        isFalse,
      );

      // Acknowledged incident stops pulse
      final ackedIncident = {
        'id': 1,
        'status': 'acknowledged',
        'severity': 'critical',
      };
      expect(
        AlertPresentationMapping.shouldPulse(incident: ackedIncident, stale: false),
        isFalse,
      );

      // Resolved incident stops pulse
      final resolvedIncident = {
        'id': 1,
        'status': 'resolved',
        'severity': 'critical',
      };
      expect(
        AlertPresentationMapping.shouldPulse(incident: resolvedIncident, stale: false),
        isFalse,
      );

      // False alarm stops pulse
      final falseAlarm = {
        'id': 1,
        'status': 'false_alarm',
        'severity': 'critical',
      };
      expect(
        AlertPresentationMapping.shouldPulse(incident: falseAlarm, stale: false),
        isFalse,
      );

      // Simulation event never pulses
      final simulationIncident = {
        'id': 1,
        'status': 'notifying',
        'severity': 'critical',
        'is_simulation': true,
      };
      expect(
        AlertPresentationMapping.shouldPulse(incident: simulationIncident, stale: false),
        isFalse,
      );

      // None / Low severity does not pulse
      final lowIncident = {
        'id': 1,
        'status': 'notifying',
        'severity': 'low',
      };
      expect(
        AlertPresentationMapping.shouldPulse(incident: lowIncident, stale: false),
        isFalse,
      );
    });
  });

  group('Gói B4: AiTelemetryEvaluator 7-Level Priority Tests', () {
    final now = DateTime(2026, 10, 17, 10, 0, 0);

    test('Rule 1: Stale data or null camera returns undefined status', () {
      final r1 = AiTelemetryEvaluator.evaluate(camera: null, now: now);
      expect(r1.ruleLevel, 1);
      expect(r1.label, 'Chưa xác định trạng thái nhận diện');
      expect(r1.isStale, isTrue);

      final cam = {
        'id': 1,
        'detect_enabled': true,
        'status': {'online': true, 'running': true},
      };
      final r1Stale = AiTelemetryEvaluator.evaluate(camera: cam, stale: true, now: now);
      expect(r1Stale.ruleLevel, 1);
      expect(r1Stale.isStale, isTrue);
    });

    test('Rule 2: Fresh runtime error takes precedence over config enabled', () {
      final cam = {
        'id': 1,
        'detect_enabled': true,
        'status': {
          'online': true,
          'running': false,
          'error': 'Hailo NPU device timeout',
        },
      };
      final res = AiTelemetryEvaluator.evaluate(camera: cam, now: now);
      expect(res.ruleLevel, 2);
      expect(res.isError, isTrue);
      expect(res.label, contains('Hailo NPU device timeout'));
      expect(res.secondaryLabel, 'Cấu hình: Bật');
    });

    test('Rule 3: Config detect_enabled == false indicates AI is off', () {
      final cam = {
        'id': 1,
        'detect_enabled': false,
        'status': {'online': true},
      };
      final res = AiTelemetryEvaluator.evaluate(camera: cam, now: now);
      expect(res.ruleLevel, 3);
      expect(res.isOff, isTrue);
      expect(res.label, 'AI đang tắt');
    });

    test('Rule 4: Detect enabled but runtime offline or not running', () {
      final offlineCam = {
        'id': 1,
        'detect_enabled': true,
        'status': {'online': false, 'running': false},
      };
      final rOffline = AiTelemetryEvaluator.evaluate(camera: offlineCam, now: now);
      expect(rOffline.ruleLevel, 4);
      expect(rOffline.label, 'Camera mất kết nối');

      final stoppedCam = {
        'id': 1,
        'detect_enabled': true,
        'status': {'online': true, 'running': false},
      };
      final rStopped = AiTelemetryEvaluator.evaluate(camera: stoppedCam, now: now);
      expect(rStopped.ruleLevel, 4);
      expect(rStopped.label, 'Nhận diện chưa hoạt động');
    });

    test('Rule 5: Detect enabled with fresh inference within threshold confirms monitoring', () {
      final cam = {
        'id': 1,
        'detect_enabled': true,
        'status': {
          'online': true,
          'running': true,
          'last_infer_at': now.subtract(const Duration(seconds: 4)).toIso8601String(),
          'ai_fps': 14.8,
        },
      };
      final res = AiTelemetryEvaluator.evaluate(camera: cam, now: now);
      expect(res.ruleLevel, 5);
      expect(res.isActive, isTrue);
      expect(res.label, 'AI đang giám sát');
      expect(res.secondaryLabel, '14.8 FPS');
    });

    test('Rule 5 Degradation: When inference is older than freshness threshold, drops to Rule 6/7', () {
      final cam = {
        'id': 1,
        'detect_enabled': true,
        'status': {
          'online': true,
          'running': true,
          'last_infer_at': now.subtract(const Duration(seconds: 45)).toIso8601String(),
          'ai_fps': 15.0,
        },
      };
      // Over 15s freshness threshold -> must NOT report "AI đang giám sát"
      final res = AiTelemetryEvaluator.evaluate(camera: cam, now: now);
      expect(res.isActive, isFalse);
      expect(res.label, isNot('AI đang giám sát'));
      expect(res.ruleLevel, 6);
      expect(res.label, 'Đã bật nhận diện');
    });

    test('Rule 6: Config enabled but no runtime status or infer data', () {
      final cam = {
        'id': 1,
        'detect_enabled': true,
      };
      final res = AiTelemetryEvaluator.evaluate(camera: cam, now: now);
      expect(res.ruleLevel, 6);
      expect(res.label, 'Đã bật nhận diện');
      expect(res.secondaryLabel, 'Chưa xác định trạng thái hoạt động');
    });
  });
}
