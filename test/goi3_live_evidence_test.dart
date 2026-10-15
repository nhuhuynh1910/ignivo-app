import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/camera/mjpeg_stream_view.dart';
import 'package:ignivo_app/features/fireguard/incident_page.dart';

final _samplePng = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
  0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1,
  13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Gói 3 - Live & Evidence features', () {
    testWidgets('GuardIncidentImage shows retry button on error and succeeds on retry', (
      tester,
    ) async {
      var callCount = 0;
      final api = FireguardApiService(
        client: MockClient((r) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Internal Error', 500);
          }
          return http.Response.bytes(_samplePng, 200, headers: {'content-type': 'image/jpeg'});
        }),
      );
      await api.setAuthToken('test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardIncidentImage(
              api: api,
              incidentId: 99,
              name: '00.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Không tải được ảnh'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Tải lại ảnh'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tải lại ảnh'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.text('Xem phóng to'), findsOneWidget);
    });

    testWidgets('GuardIncidentImage fullscreen opens InteractiveViewer with pinch-to-zoom', (
      tester,
    ) async {
      final api = FireguardApiService(
        client: MockClient((r) async {
          return http.Response.bytes(_samplePng, 200, headers: {'content-type': 'image/jpeg'});
        }),
      );
      await api.setAuthToken('test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardIncidentImage(
              api: api,
              incidentId: 99,
              name: '01.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Ảnh bằng chứng: 01.jpg'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('MjpegStreamView allows pause and resume of stream', (
      tester,
    ) async {
      final streamController = StreamController<List<int>>.broadcast();
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          streamController.stream,
          200,
          headers: {'content-type': 'multipart/x-mixed-replace; boundary=frame'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MjpegStreamView(
              streamUrl: 'http://127.0.0.1:8080/stream',
              showStats: false,
              httpClient: mockClient,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tạm dừng'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.text('Tạm dừng'));
      await tester.pumpAndSettle();

      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('Đã tạm dừng phát luồng'), findsOneWidget);

      await tester.tap(find.text('Tiếp tục'));
      await tester.pump();

      expect(find.text('Tạm dừng'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await streamController.close();
    });
  });
}
