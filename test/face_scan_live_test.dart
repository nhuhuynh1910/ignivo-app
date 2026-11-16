import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/fireeye_api_service.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';
import 'package:ignivo_app/features/camera/camera_live_page.dart';
import 'package:ignivo_app/features/camera/face_scan_result_sheet.dart';

http.Response jsonResp(Object data, [int status = 200]) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FireeyeApiService matchCameraFace Unit Tests', () {
    test('matchCameraFace sends GET to /api/faces/match-camera and parses result',
        () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/faces/match-camera') {
          return jsonResp({
            'success': true,
            'faces_detected': 1,
            'results': [
              {
                'matched': true,
                'person_id': 1,
                'name': 'Nguyen Van A',
                'role': 'Owner',
                'group_tag': 'FAMILY',
                'confidence': 0.945,
                'bbox': [100, 150, 240, 320],
              }
            ],
            'snapshot': '/static/snapshots/face_sample.jpg',
          });
        }
        return jsonResp({'detail': 'Not found'}, 404);
      });

      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: client,
      );
      await eye.configure('http://127.0.0.1:8000');

      final result = await eye.matchCameraFace();
      expect(result['success'], isTrue);
      expect(result['faces_detected'], equals(1));
      expect(result['snapshot'], equals('/static/snapshots/face_sample.jpg'));
      final list = result['results'] as List<dynamic>;
      expect(list.length, equals(1));
      expect(list[0]['name'], equals('Nguyen Van A'));
      expect(list[0]['matched'], isTrue);
    });

    test('matchCameraFace throws FireeyeException on camera snapshot error',
        () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/faces/match-camera') {
          return jsonResp({
            'success': false,
            'message': 'Không chụp được ảnh từ camera Dahua',
          });
        }
        return jsonResp({}, 400);
      });

      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: client,
      );
      await eye.configure('http://127.0.0.1:8000');

      expect(
        () => eye.matchCameraFace(),
        throwsA(isA<FireeyeException>().having(
          (e) => e.message,
          'message',
          contains('Không chụp được ảnh từ camera Dahua'),
        )),
      );
    });
  });

  group('FaceScanResultSheet UI Widget Tests', () {
    testWidgets('Renders empty state when 0 faces detected', (tester) async {
      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((_) async => jsonResp({})),
      );

      final result = {
        'success': true,
        'faces_detected': 0,
        'results': [],
        'snapshot': '',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceScanResultSheet(
              result: result,
              eye: eye,
            ),
          ),
        ),
      );

      expect(find.text('Kết quả quét gương mặt AI'), findsOneWidget);
      expect(find.text('Không tìm thấy khuôn mặt'), findsOneWidget);
      expect(find.text('Không phát hiện mục tiêu'), findsOneWidget);
    });

    testWidgets('Renders recognized person details when matched == true',
        (tester) async {
      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((request) async {
          if (request.url.path == '/static/snapshots/test.jpg') {
            return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200,
                headers: {'content-type': 'image/jpeg'});
          }
          return jsonResp({});
        }),
      );

      final result = {
        'success': true,
        'faces_detected': 1,
        'results': [
          {
            'matched': true,
            'person_id': 12,
            'name': 'Nguyễn Văn A',
            'role': 'Owner',
            'group_tag': 'FAMILY',
            'confidence': 0.952,
          }
        ],
        'snapshot': '/static/snapshots/test.jpg',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceScanResultSheet(
              result: result,
              eye: eye,
            ),
          ),
        ),
      );

      expect(find.text('Kết quả quét gương mặt AI'), findsOneWidget);
      expect(find.text('Phát hiện 1 khuôn mặt'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Người quen'), findsOneWidget);
      expect(find.text('Gia đình'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('95.2% tương đồng'), findsOneWidget);
    });

    testWidgets(
        'Renders unknown person state and triggers onOpenPeoplePage',
        (tester) async {
      final eye = FireeyeApiService(
        fireguard: FireguardApiService(),
        client: MockClient((_) async => jsonResp({})),
      );

      bool openedPeoplePage = false;

      final result = {
        'success': true,
        'faces_detected': 1,
        'results': [
          {
            'matched': false,
            'name': 'Unknown',
            'confidence': 0.231,
          }
        ],
        'snapshot': '',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceScanResultSheet(
              result: result,
              eye: eye,
              onOpenPeoplePage: () {
                openedPeoplePage = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('Người lạ'), findsOneWidget);
      expect(find.text('23.1% tương đồng'), findsOneWidget);

      final registerBtn = find.text('Đăng ký vào hệ thống');
      expect(registerBtn, findsOneWidget);

      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(openedPeoplePage, isTrue);
    });
  });

  group('CameraLivePage Quét gương mặt Toolbar Integration', () {
    testWidgets('Contains Quét gương mặt button in toolbar', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FireguardApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/cameras') {
            return jsonResp([
              {
                'id': 1,
                'name': 'Camera Cổng Trước',
                'is_active': true,
                'is_connected': true,
                'rtsp_url': 'rtsp://mock',
              }
            ]);
          }
          return jsonResp({});
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CameraLivePage(
            cameraId: 1,
            api: api,
            initialCamera: const {
              'id': 1,
              'name': 'Camera Cổng Trước',
              'is_active': true,
              'is_connected': true,
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Quét gương mặt'), findsOneWidget);
      expect(find.byIcon(Icons.face_retouching_natural_rounded), findsOneWidget);
    });
  });
}

