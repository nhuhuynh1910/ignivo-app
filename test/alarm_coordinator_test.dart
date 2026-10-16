import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/alert_feedback_adapter.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_realtime_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';

class MockAlertFeedbackAdapter implements AlertFeedbackAdapter {
  int warningChimesPlayed = 0;
  int sirenStartCount = 0;
  int sirenStopCount = 0;
  int vibrationCount = 0;
  bool isSirenActive = false;
  String? error;

  @override
  String? get lastError => error;

  @override
  bool get isSirenPlaying => isSirenActive;

  @override
  Future<void> playWarningChime() async {
    warningChimesPlayed++;
  }

  @override
  Future<void> startAlarmSiren() async {
    sirenStartCount++;
    isSirenActive = true;
  }

  @override
  Future<void> stopAlarmSiren() async {
    sirenStopCount++;
    isSirenActive = false;
  }

  @override
  Future<void> triggerVibrationPattern() async {
    vibrationCount++;
  }

  @override
  Future<void> cancelVibration() async {}

  @override
  void dispose() {
    stopAlarmSiren();
  }
}

class FakeRealtimeService extends FireguardRealtimeService {
  FakeRealtimeService(super.api);
  final controller = StreamController<FireguardEvent>.broadcast();

  @override
  Stream<FireguardEvent> get events => controller.stream;

  void emit(String name, Map<String, dynamic> data) {
    controller.add(FireguardEvent(name, data));
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IncidentAlertCoordinator Tests', () {
    late FireguardApiService api;
    late FakeRealtimeService realtime;
    late MockAlertFeedbackAdapter feedback;
    late IncidentAlertCoordinator coordinator;

    setUp(() {
      api = FireguardApiService(client: MockClient((_) async => throw UnimplementedError()));
      realtime = FakeRealtimeService(api);
      feedback = MockAlertFeedbackAdapter();
      coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: feedback,
        sirenWatchdogDuration: const Duration(seconds: 1),
      );
    });

    tearDown(() {
      coordinator.dispose();
      realtime.dispose();
    });

    test('Created event with null severity triggers warning chime once', () async {
      realtime.emit('incident.created', {
        'id': 101,
        'status': 'analyzing',
        'severity': null,
        'camera_name': 'Kho A',
        'area': 'Tang 1',
      });
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.level, AlertLevel.warning);
      expect(coordinator.isSilenced, isFalse);
      expect(feedback.warningChimesPlayed, 1);
      expect(feedback.isSirenActive, isFalse);
    });

    test('Escalation to high severity triggers urgent siren loop', () async {
      // 1. Initial creation (warning)
      realtime.emit('incident.created', {
        'id': 102,
        'status': 'analyzing',
        'severity': null,
      });
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.level, AlertLevel.warning);
      expect(feedback.isSirenActive, isFalse);

      // 2. Analyzed escalation to high
      realtime.emit('incident.analyzed', {
        'id': 102,
        'status': 'active',
        'severity': 'high',
      });
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.level, AlertLevel.urgent);
      expect(coordinator.isSilenced, isFalse);
      expect(feedback.sirenStartCount, 1);
      expect(feedback.isSirenActive, isTrue);
    });

    test('Silence button stops siren on phone without API ACK', () async {
      realtime.emit('incident.analyzed', {
        'id': 103,
        'status': 'active',
        'severity': 'critical',
      });
      await Future<void>.delayed(Duration.zero);

      expect(feedback.isSirenActive, isTrue);

      // User presses "Tắt còi trên điện thoại"
      coordinator.silenceAlarm();

      expect(coordinator.isSilenced, isTrue);
      expect(coordinator.level, AlertLevel.urgent);
      expect(feedback.isSirenActive, isFalse);
      expect(feedback.sirenStopCount, 1);

      // Duplicate or same-level event arriving later does NOT re-trigger siren
      realtime.emit('incident.updated', {
        'id': 103,
        'status': 'active',
        'severity': 'critical',
      });
      await Future<void>.delayed(Duration.zero);

      expect(feedback.sirenStartCount, 1);
      expect(feedback.isSirenActive, isFalse);
    });

    test('Incident resolved or closed stops alert immediately', () async {
      realtime.emit('incident.created', {
        'id': 104,
        'status': 'active',
        'severity': 'high',
      });
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isTrue);

      // External resolution (e.g. from dashboard or another staff member)
      realtime.emit('incident.closed', {
        'id': 104,
        'status': 'resolved',
      });
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.level, AlertLevel.none);
      expect(coordinator.currentIncident, isNull);
      expect(feedback.isSirenActive, isFalse);
    });

    test('Simulation incidents do not trigger audible siren unless test mode is enabled', () async {
      realtime.emit('incident.created', {
        'id': 105,
        'status': 'active',
        'severity': 'critical',
        'is_simulation': true,
      });
      await Future<void>.delayed(Duration.zero);

      // Muted by default
      expect(coordinator.isSilenced, isTrue);
      expect(feedback.isSirenActive, isFalse);
      expect(feedback.warningChimesPlayed, 0);

      // When user enables simulationAudible
      coordinator.simulationAudible = true;
      realtime.emit('incident.analyzed', {
        'id': 105,
        'status': 'active',
        'severity': 'critical',
        'is_simulation': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(feedback.isSirenActive, isTrue);
    });

    test('Reconnect syncActiveIncidents deduplicates and maintains state', () async {
      coordinator.syncActiveIncidents([
        {
          'id': 106,
          'status': 'active',
          'severity': 'high',
        }
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.level, AlertLevel.urgent);
      expect(feedback.sirenStartCount, 1);

      // Reconnect resync with identical incident does not duplicate siren start
      coordinator.syncActiveIncidents([
        {
          'id': 106,
          'status': 'active',
          'severity': 'high',
        }
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(feedback.sirenStartCount, 1);
    });

    test('Two simultaneous incidents: ACK on incident A keeps siren active for incident B', () async {
      realtime.emit('incident.analyzed', {'id': 201, 'status': 'notifying', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isTrue);

      realtime.emit('incident.analyzed', {'id': 202, 'status': 'notifying', 'severity': 'critical'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isTrue);

      // ACK incident A
      realtime.emit('incident.updated', {'id': 201, 'status': 'acknowledged', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);

      // Siren MUST stay active because incident B is still active and urgent
      expect(feedback.isSirenActive, isTrue);
      expect(coordinator.currentIncident?.incidentId, 202);

      // ACK incident B
      realtime.emit('incident.updated', {'id': 202, 'status': 'acknowledged', 'severity': 'critical'});
      await Future<void>.delayed(Duration.zero);

      // Now all urgent incidents are acknowledged, siren must stop
      expect(feedback.isSirenActive, isFalse);
      expect(coordinator.level, AlertLevel.none);
    });

    test('Escalation from high to critical re-alerts when high was silenced', () async {
      realtime.emit('incident.analyzed', {'id': 203, 'status': 'notifying', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isTrue);

      // User silences high alarm
      coordinator.silenceAlarm();
      expect(feedback.isSirenActive, isFalse);
      expect(coordinator.isSilenced, isTrue);

      // Escalation to critical
      realtime.emit('incident.updated', {'id': 203, 'status': 'notifying', 'severity': 'critical'});
      await Future<void>.delayed(Duration.zero);

      // Must re-alert for critical
      expect(feedback.isSirenActive, isTrue);
      expect(coordinator.isSilenced, isFalse);
    });

    test('call.updated events are ignored by coordinator and do not overwrite incident state', () async {
      realtime.emit('incident.analyzed', {'id': 204, 'status': 'notifying', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.currentIncident?.incidentId, 204);
      expect(coordinator.level, AlertLevel.urgent);

      // Unrelated phone call event arrives with incident_id but no severity/status
      realtime.emit('call.updated', {'incident_id': 204, 'call_status': 'ringing'});
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.currentIncident?.incidentId, 204);
      expect(coordinator.level, AlertLevel.urgent);
      expect(feedback.isSirenActive, isTrue);
    });

    test('Stale non-terminal event arriving after ACK does not resurrect siren', () async {
      realtime.emit('incident.analyzed', {'id': 205, 'status': 'notifying', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isTrue);

      // External ACK arrives
      realtime.emit('incident.updated', {'id': 205, 'status': 'acknowledged', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isFalse);

      // Delayed duplicate notifying event arrives
      realtime.emit('incident.updated', {'id': 205, 'status': 'notifying', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isFalse);
      expect(coordinator.level, AlertLevel.none);
    });

    test('pauseFeedback stops hardware audio and resumeFeedback restores it', () async {
      realtime.emit('incident.analyzed', {'id': 206, 'status': 'notifying', 'severity': 'high'});
      await Future<void>.delayed(Duration.zero);
      expect(feedback.isSirenActive, isTrue);

      // App transitions to background
      coordinator.pauseFeedback();
      expect(feedback.isSirenActive, isFalse);
      expect(coordinator.level, AlertLevel.urgent);

      // App returns to foreground
      coordinator.resumeFeedback();
      expect(feedback.isSirenActive, isTrue);
    });
  });
}
