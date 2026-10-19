import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';
import 'pulsing_status_dot.dart';

enum IncidentStepState {
  completed,
  active,
  warning,
  pending,
}

/// Thẻ dòng thời gian tiến trình phản ứng sự cố thông minh (Visual Stepper Timeline)
///
/// Trực quan hóa quy trình xử lý khẩn cấp 4 bước:
/// 1. Phát hiện ➔ 2. AI Xác thực ➔ 3. Báo động & Gọi điện ➔ 4. Xử lý & Kết thúc.
class IncidentTimelineStepper extends StatelessWidget {
  const IncidentTimelineStepper({
    super.key,
    required this.incident,
  });

  final Map<String, dynamic> incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final status = incident['status']?.toString() ?? 'analyzing';
    final triggerType = incident['trigger_type']?.toString().toUpperCase() ?? 'FIRE';
    final isSimulation = incident['is_simulation'] == true || triggerType.toLowerCase() == 'simulation';
    final calls = (incident['calls'] as List? ?? []);
    final analysis = incident['analysis'] as Map?;

    // Xác định trạng thái của từng bước
    final step1State = IncidentStepState.completed; // Luôn hoàn thành vì sự cố đã sinh ra

    final IncidentStepState step2State;
    if (status == 'analyzing') {
      step2State = IncidentStepState.active;
    } else if (status == 'ai_dismissed') {
      step2State = IncidentStepState.warning;
    } else {
      step2State = IncidentStepState.completed;
    }

    final IncidentStepState step3State;
    if (status == 'ai_dismissed') {
      step3State = IncidentStepState.pending;
    } else if (status == 'notifying') {
      step3State = IncidentStepState.active;
    } else if (['notified', 'acknowledged', 'resolved', 'false_alarm'].contains(status)) {
      step3State = IncidentStepState.completed;
    } else {
      step3State = IncidentStepState.pending;
    }

    final IncidentStepState step4State;
    if (['resolved', 'false_alarm'].contains(status)) {
      step4State = IncidentStepState.completed;
    } else if (status == 'acknowledged') {
      step4State = IncidentStepState.active;
    } else {
      step4State = IncidentStepState.pending;
    }

    // Nhãn phụ từng bước
    final step1Sub = isSimulation ? 'Mô phỏng' : triggerType;
    final modelName = analysis?['model']?.toString();
    final step2Sub = status == 'analyzing'
        ? 'Đang quét'
        : (status == 'ai_dismissed'
            ? 'Không phải cháy'
            : (modelName != null && modelName.isNotEmpty ? modelName : 'Đã xác thực'));
    final step3Sub = status == 'notifying'
        ? 'Đang gọi'
        : (calls.isNotEmpty ? '${calls.length} cuộc gọi' : (status == 'ai_dismissed' ? 'Bỏ qua' : 'Sẵn sàng'));
    final step4Sub = status == 'resolved'
        ? 'Đã xử lý'
        : (status == 'false_alarm'
            ? 'Báo nhầm'
            : (status == 'acknowledged' ? 'Đang xử lý' : 'Chờ xử lý'));

    // Thông điệp trạng thái chi tiết
    final String currentStatusMessage;
    final Color currentStatusColor;
    if (status == 'analyzing') {
      currentStatusMessage = 'AI Edge đang phân tích luồng video và đánh giá nguy cơ cháy...';
      currentStatusColor = BrandTokens.stitchWarningFg;
    } else if (status == 'ai_dismissed') {
      currentStatusMessage = 'AI nhận định không phát hiện ngọn lửa nguy hiểm; hãy rà soát ảnh bằng chứng.';
      currentStatusColor = BrandTokens.stitchWarningFg;
    } else if (status == 'notifying') {
      currentStatusMessage = 'Đang tự động kích hoạt cuộc gọi Stringee đến các số điện thoại khẩn cấp.';
      currentStatusColor = BrandTokens.stitchCriticalFg;
    } else if (status == 'acknowledged') {
      currentStatusMessage = 'Lực lượng trực ban đã tiếp nhận sự cố và đang triển khai xử lý tại chỗ.';
      currentStatusColor = BrandTokens.brandPrimary;
    } else if (status == 'resolved') {
      currentStatusMessage = 'Sự cố đã được kiểm soát và kết thúc an toàn.';
      currentStatusColor = BrandTokens.stitchOnlineFg;
    } else if (status == 'false_alarm') {
      currentStatusMessage = 'Sự cố được xác nhận là báo động nhầm. Đã đóng phiên ghi nhận.';
      currentStatusColor = isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary;
    } else {
      currentStatusMessage = 'Đã hoàn thành các chu trình thông báo khẩn cấp.';
      currentStatusColor = BrandTokens.brandPrimary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : BrandTokens.surface,
        borderRadius: BorderRadius.circular(BrandTokens.stitchCardRadius),
        border: Border.all(
          color: (isDark ? BrandTokens.darkBorder : BrandTokens.border).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tiêu đề của Stepper
          Row(
            children: [
              Icon(
                Icons.alt_route_rounded,
                size: 16,
                color: isDark ? BrandTokens.stitchDarkPrimary : BrandTokens.brandPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tiến trình xử lý sự cố',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSimulation) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mô phỏng',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Hàng Stepper 4 bước
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepItem(
                context,
                stepNumber: 1,
                title: 'Phát hiện',
                subtitle: step1Sub,
                icon: Icons.sensors_rounded,
                state: step1State,
                isDark: isDark,
              ),
              _buildConnectingLine(
                isCompleted: step2State == IncidentStepState.completed || step2State == IncidentStepState.active,
                isDark: isDark,
              ),
              _buildStepItem(
                context,
                stepNumber: 2,
                title: 'AI Xác thực',
                subtitle: step2Sub,
                icon: Icons.smart_toy_rounded,
                state: step2State,
                isDark: isDark,
              ),
              _buildConnectingLine(
                isCompleted: step3State == IncidentStepState.completed || step3State == IncidentStepState.active,
                isDark: isDark,
              ),
              _buildStepItem(
                context,
                stepNumber: 3,
                title: 'Báo động',
                subtitle: step3Sub,
                icon: Icons.phone_in_talk_rounded,
                state: step3State,
                isDark: isDark,
              ),
              _buildConnectingLine(
                isCompleted: step4State == IncidentStepState.completed || step4State == IncidentStepState.active,
                isDark: isDark,
              ),
              _buildStepItem(
                context,
                stepNumber: 4,
                title: 'Hiện trường',
                subtitle: step4Sub,
                icon: Icons.verified_user_rounded,
                state: step4State,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hộp thông điệp diễn giải trạng thái hiện thời
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: currentStatusColor.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(BrandTokens.stitchSmallCardRadius),
              border: Border.all(
                color: currentStatusColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                if (status == 'analyzing' || status == 'notifying')
                  PulsingStatusDot(
                    color: currentStatusColor,
                    size: 8,
                    pulseSize: 16,
                  )
                else
                  Icon(
                    status == 'resolved'
                        ? Icons.check_circle_rounded
                        : (status == 'ai_dismissed' ? Icons.info_rounded : Icons.radio_button_checked_rounded),
                    size: 14,
                    color: currentStatusColor,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentStatusMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? BrandTokens.darkTextPrimary : BrandTokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingLine({
    required bool isCompleted,
    required bool isDark,
  }) {
    return Expanded(
      flex: 2,
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(top: 14),
        color: isCompleted
            ? BrandTokens.stitchOnlineFg
            : (isDark ? BrandTokens.darkBorder : BrandTokens.border),
      ),
    );
  }

  Widget _buildStepItem(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required IncidentStepState state,
    required bool isDark,
  }) {
    final Color circleBg;
    final Color circleFg;
    final Color circleBorder;

    switch (state) {
      case IncidentStepState.completed:
        circleBg = isDark ? BrandTokens.stitchDarkOnlineBg : BrandTokens.stitchOnlineBg;
        circleFg = isDark ? BrandTokens.stitchDarkOnlineFg : BrandTokens.stitchOnlineFg;
        circleBorder = circleFg.withValues(alpha: 0.5);
      case IncidentStepState.active:
        circleBg = isDark ? BrandTokens.darkBrandTint : BrandTokens.brandTint;
        circleFg = isDark ? BrandTokens.stitchDarkPrimary : BrandTokens.brandPrimary;
        circleBorder = circleFg;
      case IncidentStepState.warning:
        circleBg = isDark ? BrandTokens.stitchDarkWarningBg : BrandTokens.stitchWarningBg;
        circleFg = isDark ? BrandTokens.stitchDarkWarningFg : BrandTokens.stitchWarningFg;
        circleBorder = circleFg.withValues(alpha: 0.6);
      case IncidentStepState.pending:
        circleBg = isDark ? BrandTokens.darkBackground : BrandTokens.background;
        circleFg = isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary;
        circleBorder = (isDark ? BrandTokens.darkBorder : BrandTokens.border).withValues(alpha: 0.8);
    }

    return Expanded(
      flex: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vòng tròn icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
              border: Border.all(color: circleBorder, width: state == IncidentStepState.active ? 2 : 1),
            ),
            child: Icon(
              state == IncidentStepState.completed
                  ? Icons.check_rounded
                  : (state == IncidentStepState.warning ? Icons.priority_high_rounded : icon),
              size: 15,
              color: circleFg,
            ),
          ),
          const SizedBox(height: 5),

          // Tên bước
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: state == IncidentStepState.active ? FontWeight.bold : FontWeight.w600,
              color: state == IncidentStepState.active
                  ? (isDark ? BrandTokens.stitchDarkPrimary : BrandTokens.brandPrimary)
                  : (state == IncidentStepState.completed
                      ? (isDark ? BrandTokens.stitchDarkOnlineFg : BrandTokens.stitchOnlineFg)
                      : (isDark ? BrandTokens.darkTextTertiary : BrandTokens.textTertiary)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),

          // Trạng thái / phụ đề
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.normal,
              color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
