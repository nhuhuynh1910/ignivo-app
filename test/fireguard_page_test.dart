import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_realtime_service.dart';
import 'package:ignivo_app/features/fireguard/fireguard_page.dart';

class TestRealtime extends FireguardRealtimeService {
  TestRealtime(super.api);
  final controller = StreamController<FireguardEvent>.broadcast();
  @override
  Stream<FireguardEvent> get events => controller.stream;
  void connection(FireguardConnection value) {
    state = value;
    notifyListeners();
  }

  @override
  void start() => connection(FireguardConnection.connected);
  @override
  void stop() => connection(FireguardConnection.stopped);
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

void main() {
  testWidgets(
    'FireGuard owns dashboard; WS refreshes incidents and reconnect resyncs active',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      var incident = <String, dynamic>{
        'id': 72,
        'trigger_type': 'fire',
        'status': 'analyzing',
        'severity': 'high',
      };
      var activeReads = 0;
      final paths = <String>[];
      final api = FireguardApiService(
        client: MockClient((r) async {
          expectSync(r.url.port, 8080);
          expectSync(r.headers['Authorization'], 'Bearer test');
          paths.add(r.url.path);
          final suffix = r.url.path.replaceFirst('/api/v1/emergency', '');
          Object? value;
          switch (suffix) {
            case '/auth/me':
              value = {'role': 'OWNER'};
            case '/system/info':
              value = {'hostname': 'Pi5'};
            case '/status':
              value = {
                'detection_source': 'local',
                'vision': {'ready': true},
                'gemini_configured': true,
              };
            case '/cameras':
              value = [
                {
                  'id': 1,
                  'name': 'Camera 1',
                  'status': {'online': false},
                },
              ];
            case '/incidents':
              value = [incident];
            case '/incidents/active':
              activeReads++;
              value = incident;
            case '/incidents/72':
              value = incident;
            default:
              fail('Unexpected route: $suffix');
          }
          return http.Response(jsonEncode(value), 200);
        }),
      );
      await api.setBaseUrl('http://pi:8080');
      await api.setAuthToken('test');
      final realtime = TestRealtime(api);
      await tester.pumpWidget(
        MaterialApp(
          home: FireguardPage(api: api, realtime: realtime),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã kết nối cảnh báo trực tiếp'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sự cố đang mở #72'), 200);
      expect(activeReads, greaterThan(0));
      final before = activeReads;
      realtime.connection(FireguardConnection.reconnecting);
      realtime.connection(FireguardConnection.connected);
      // HTTP streams span several microtask batches; settling a frame alone
      // does not imply that all sequential API reads have completed.
      for (var i = 0; i < 20 && activeReads == before; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(activeReads, greaterThan(before));
      await tester.scrollUntilVisible(find.text('Camera 1'), 200);
      await tester.scrollUntilVisible(
        find.text('Không có hình trực tiếp'),
        200,
      );
      expect(find.text('Không có hình trực tiếp'), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Tất cả'), findsOneWidget);
      await tester.tap(find.text('Đã đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Không có sự cố trong nhóm này.'), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Thêm camera'), findsOneWidget);
      expect(find.text('Chỉnh sửa'), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Nhận diện trên Pi'), 200);
      await Scrollable.ensureVisible(
        tester.element(find.text('Nhận diện trên Pi')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhận diện trên Pi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('/ui/#settings'), findsOneWidget);
      realtime.controller.add(FireguardEvent('incident.created', incident));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('CẢNH BÁO: FireGuard phát hiện sự cố #72'),
        findsOneWidget,
      );
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
      expect(find.text('Sự cố #72'), findsOneWidget);
      expect(find.text('Đang phân tích'), findsOneWidget);
      incident = {...incident, 'status': 'notified'};
      realtime.controller.add(
        const FireguardEvent('call.updated', {'incident_id': 72}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã kết thúc lượt gọi'), findsOneWidget);
      expect(paths.every((p) => p.startsWith('/api/v1/emergency/')), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
