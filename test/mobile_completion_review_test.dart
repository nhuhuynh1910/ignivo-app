import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'alarm_coordinator_test.dart'
    show FakeRealtimeService, MockAlertFeedbackAdapter;

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
    coordinator = IncidentAlertCoordinator(
      api: api,
      realtime: realtime,
      feedbackAdapter: feedback,
    );
  });
  tearDown(() {
    coordinator.dispose();
    realtime.dispose();
  });
  Future<void> emit(Map<String, dynamic> data) async {
    realtime.emit('incident.updated', data);
    await Future<void>.delayed(Duration.zero);
  }

  test('older critical update after ACK must not restart siren', () async {
    await emit({
      'id': 1,
      'status': 'notifying',
      'severity': 'high',
      'updated_at': '2026-10-15T10:00:00Z',
    });
    await emit({
      'id': 1,
      'status': 'acknowledged',
      'severity': 'high',
      'updated_at': '2026-10-15T10:02:00Z',
    });
    await emit({
      'id': 1,
      'status': 'notifying',
      'severity': 'critical',
      'updated_at': '2026-10-15T10:01:00Z',
    });
    expect(feedback.isSirenActive, isFalse);
  });
  test(
    'silence remains able to silence second incident after critical is muted',
    () async {
      await emit({'id': 1, 'status': 'notifying', 'severity': 'critical'});
      await emit({'id': 2, 'status': 'notifying', 'severity': 'high'});
      coordinator.silenceAlarm();
      coordinator.silenceAlarm();
      expect(feedback.isSirenActive, isFalse);
    },
  );
  testWidgets('watchdog stops all simultaneous audible incidents', (
    tester,
  ) async {
    coordinator.syncActiveIncidents([
      {'id': 1, 'status': 'notifying', 'severity': 'critical'},
      {'id': 2, 'status': 'notifying', 'severity': 'high'},
    ]);
    coordinator.silenceAlarm();
    expect(feedback.isSirenActive, isTrue);
    await tester.pump(const Duration(seconds: 61));
    expect(feedback.isSirenActive, isFalse);
  });
}
