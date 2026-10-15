import 'dart:async';
import 'package:flutter/services.dart';

/// Abstract adapter for hardware audio and haptic feedback.
/// Allows unit and widget testing with mock implementations without physical device dependencies.
abstract class AlertFeedbackAdapter {
  Future<void> playWarningChime();
  Future<void> startAlarmSiren();
  Future<void> stopAlarmSiren();
  Future<void> triggerVibrationPattern();
  Future<void> cancelVibration();
  void dispose();
}

/// Default system feedback adapter using Flutter platform services.
class SystemAlertFeedbackAdapter implements AlertFeedbackAdapter {
  Timer? _sirenTimer;
  bool _isPlayingSiren = false;

  @override
  Future<void> playWarningChime() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Platform may fail silently if system sounds are disabled.
    }
  }

  @override
  Future<void> startAlarmSiren() async {
    if (_isPlayingSiren) return;
    _isPlayingSiren = true;
    _pulse();
    _sirenTimer?.cancel();
    _sirenTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (_isPlayingSiren) {
        _pulse();
      }
    });
  }

  void _pulse() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  @override
  Future<void> stopAlarmSiren() async {
    _isPlayingSiren = false;
    _sirenTimer?.cancel();
    _sirenTimer = null;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  @override
  Future<void> triggerVibrationPattern() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  @override
  Future<void> cancelVibration() async {
    // Single vibration pulses finish on their own; timer cancellation stops loops.
  }

  @override
  void dispose() {
    stopAlarmSiren();
  }
}
