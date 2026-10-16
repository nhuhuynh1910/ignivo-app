import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/incident_alert_coordinator.dart';
import 'package:ignivo_app/core/services/fireguard_realtime_service.dart';
import 'package:ignivo_app/features/fireguard/fireguard_page.dart';
import 'fireguard_page_test.dart' show TestRealtime;
import 'alarm_coordinator_test.dart' show MockAlertFeedbackAdapter;

void main() {
  testWidgets('polling response overtaken by WS never changes audio state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var severity = 'low';
    Completer<http.Response>? pending;
    final api = FireguardApiService(
      client: MockClient((r) async {
        final path = r.url.path.replaceFirst('/api/v1/emergency', '');
        if (path == '/incidents/active' && pending != null) {
          return pending.future;
        }
        final inc = {'id': 1, 'status': 'notifying', 'severity': severity};
        final Object value = switch (path) {
          '/auth/me' => {'role': 'OWNER'},
          '/cameras' => [],
          '/incidents' => [inc],
          '/incidents/active' || '/incidents/1' => inc,
          _ => {},
        };
        return http.Response(jsonEncode(value), 200);
      }),
    );
    await api.setAuthToken('test');
    final realtime = TestRealtime(api);
    final feedback = MockAlertFeedbackAdapter();
    final coordinator = IncidentAlertCoordinator(
      api: api,
      realtime: realtime,
      feedbackAdapter: feedback,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FireguardPage(
          api: api,
          realtime: realtime,
          coordinator: coordinator,
        ),
      ),
    );
    await tester.pumpAndSettle();
    pending = Completer<http.Response>();
    realtime.connection(FireguardConnection.connected);
    await tester.pump();
    severity = 'critical';
    realtime.controller.add(
      FireguardEvent('incident.updated', {
        'id': 1,
        'status': 'notifying',
        'severity': severity,
      }),
    );
    await tester.pump();
    expect(feedback.isSirenActive, isTrue);
    final stops = feedback.sirenStopCount;
    pending.complete(
      http.Response(
        jsonEncode({'id': 1, 'status': 'notifying', 'severity': 'low'}),
        200,
      ),
    );
    pending = null;
    await tester.pumpAndSettle();
    expect(feedback.sirenStopCount, stops);
    expect(feedback.isSirenActive, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  testWidgets(
    'resume stays silent until missing tracked incident is reconciled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = false;
      var detailReads = 0;
      Completer<http.Response>? pendingStatus;
      Map<String, dynamic> incident() => {
        'id': 1,
        'status': closed ? 'resolved' : 'notifying',
        'severity': 'high',
      };
      final api = FireguardApiService(
        client: MockClient((r) async {
          final path = r.url.path.replaceFirst('/api/v1/emergency', '');
          if (path == '/status' && pendingStatus != null) {
            return pendingStatus.future;
          }
          Object? value = {};
          switch (path) {
            case '/auth/me':
              value = {'role': 'OWNER'};
            case '/cameras':
              value = [];
            case '/incidents':
              value = closed ? [] : [incident()];
            case '/incidents/active':
              value = closed ? null : incident();
            case '/incidents/1':
              detailReads++;
              value = incident();
          }
          return http.Response(jsonEncode(value), 200);
        }),
      );
      await api.setAuthToken('test');
      final realtime = TestRealtime(api);
      final feedback = MockAlertFeedbackAdapter();
      final coordinator = IncidentAlertCoordinator(
        api: api,
        realtime: realtime,
        feedbackAdapter: feedback,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FireguardPage(
            api: api,
            realtime: realtime,
            coordinator: coordinator,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(feedback.isSirenActive, isTrue);
      final starts = feedback.sirenStartCount;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(feedback.isSirenActive, isFalse);
      closed = true;
      pendingStatus = Completer<http.Response>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        feedback.sirenStartCount,
        starts,
        reason: 'Do not sound cached incident on resume',
      );
      pendingStatus.complete(http.Response('{}', 200));
      pendingStatus = null;
      await tester.pumpAndSettle();
      expect(detailReads, greaterThan(0));
      expect(feedback.isSirenActive, isFalse);
      expect(feedback.sirenStartCount, starts);
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    },
  );
}
