import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'alarm_coordinator_test.dart' show FakeRealtimeService, MockAlertFeedbackAdapter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRealtimeService realtime;
  late MockAlertFeedbackAdapter feedback;
  late IncidentAlertCoordinator coordinator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final api = FireguardApiService();
    realtime = FakeRealtimeService(api);
    feedback = MockAlertFeedbackAdapter();
    coordinator = IncidentAlertCoordinator(api: api, realtime: realtime, feedbackAdapter: feedback);
  });

  tearDown(() {
    coordinator.dispose();
    realtime.dispose();
  });

  Future<void> emit(Map<String, dynamic> data) async {
    realtime.emit('incident.updated', data);
    await Future<void>.delayed(Duration.zero);
  }

  test('latest-only polling must not erase another urgent incident', () async {
    await emit({'id': 1, 'status': 'notifying', 'severity': 'high'});
    await emit({'id': 2, 'status': 'analyzing', 'severity': 'low'});
    coordinator.syncActiveIncidents([{'id': 2, 'status': 'analyzing', 'severity': 'low'}]);
    expect(feedback.isSirenActive, isTrue);
  });

  test('older server update must not downgrade newer critical state', () async {
    await emit({'id': 1, 'status': 'notifying', 'severity': 'critical', 'updated_at': '2026-10-15T10:01:00Z'});
    await emit({'id': 1, 'status': 'analyzing', 'severity': 'low', 'updated_at': '2026-10-15T10:00:00Z'});
    expect(coordinator.currentIncident?.severity, 'critical');
    expect(feedback.isSirenActive, isTrue);
  });

  test('newer legitimate escalation after AI dismissal must alert', () async {
    await emit({'id': 1, 'status': 'ai_dismissed', 'severity': 'low', 'updated_at': '2026-10-15T10:00:00Z'});
    await emit({'id': 1, 'status': 'notifying', 'severity': 'critical', 'updated_at': '2026-10-15T10:01:00Z'});
    expect(feedback.isSirenActive, isTrue);
  });
}
