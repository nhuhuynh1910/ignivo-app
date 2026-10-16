import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Abstract adapter for hardware audio and haptic feedback.
/// Allows unit and widget testing with mock implementations without physical device dependencies.
abstract class AlertFeedbackAdapter {
  String? get lastError;
  bool get isSirenPlaying;
  Future<void> playWarningChime();
  Future<void> startAlarmSiren();
  Future<void> stopAlarmSiren();
  Future<void> triggerVibrationPattern();
  Future<void> cancelVibration();
  void dispose();
}

/// Default system feedback adapter using audioplayers and platform haptics.
class SystemAlertFeedbackAdapter implements AlertFeedbackAdapter {
  SystemAlertFeedbackAdapter({AudioPlayer? player, AudioPlayer? chimePlayer})
      : _sirenPlayer = player ?? AudioPlayer(),
        _chimePlayer = chimePlayer ?? AudioPlayer();

  final AudioPlayer _sirenPlayer;
  final AudioPlayer _chimePlayer;
  Timer? _vibrationTimer;
  bool _isPlayingSiren = false;
  String? _lastError;
  int _sirenGen = 0;

  @override
  String? get lastError => _lastError;

  @override
  bool get isSirenPlaying => _isPlayingSiren;

  @override
  Future<void> playWarningChime() async {
    _lastError = null;
    // Chuông nhẹ của sự cố B không được thay thế hoặc làm gián đoạn còi khẩn cấp A
    if (!_isPlayingSiren) {
      try {
        await _chimePlayer.setReleaseMode(ReleaseMode.release);
        await _chimePlayer.play(AssetSource('sounds/warning_chime.wav'));
      } catch (e) {
        _lastError = 'Không thể phát âm báo: $e';
      }
    }
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  @override
  Future<void> startAlarmSiren() async {
    final gen = ++_sirenGen;
    if (_isPlayingSiren) return;
    _isPlayingSiren = true;
    _lastError = null;

    try {
      await _sirenPlayer.setReleaseMode(ReleaseMode.loop);
      await _sirenPlayer.play(AssetSource('sounds/alarm_siren.wav'));
      // Nếu có lệnh stop/ACK gọi trước khi play() hoàn tất, dừng ngay lập tức
      if (gen != _sirenGen || !_isPlayingSiren) {
        await _sirenPlayer.stop();
        return;
      }
    } catch (e) {
      if (gen == _sirenGen) {
        _lastError = 'Không thể phát còi báo động: $e';
        _isPlayingSiren = false;
      }
      return;
    }

    if (_isPlayingSiren && gen == _sirenGen) {
      _triggerVibrationLoop();
    }
  }

  void _triggerVibrationLoop() {
    _vibrationTimer?.cancel();
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (_isPlayingSiren) {
        try {
          HapticFeedback.vibrate();
        } catch (_) {}
      }
    });
  }

  @override
  Future<void> stopAlarmSiren() async {
    _sirenGen++;
    _isPlayingSiren = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await _sirenPlayer.stop();
    } catch (e) {
      _lastError = 'Không thể dừng còi: $e';
    }
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
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  @override
  void dispose() {
    stopAlarmSiren();
    _sirenPlayer.dispose();
    _chimePlayer.dispose();
  }
}
