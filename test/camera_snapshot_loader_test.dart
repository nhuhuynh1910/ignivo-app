import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignivo_app/core/services/camera_snapshot_loader.dart';
import 'package:ignivo_app/core/services/fireguard_api_service.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraSnapshotLoader Unit Tests', () {
    late FireguardApiService api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = FireguardApiService();
      api.setBaseUrl('http://192.168.1.100:8000');
      await api.setAuthToken('mock-token');
    });

    test('getCachedSnapshot returns null initially', () {
      final loader = CameraSnapshotLoader(api: api);
      expect(loader.getCachedSnapshot(1), isNull);
    });

    test('loadSnapshot respects failure caching cooldown', () async {
      final loader = CameraSnapshotLoader(api: api);

      // First call fails because mock test binding returns 400 or network error
      final result1 = await loader.loadSnapshot(999);
      expect(result1.isSuccess, isFalse);

      // Second call immediately returns the cached failure without re-fetching
      final result2 = await loader.loadSnapshot(999);
      expect(result2.isSuccess, isFalse);
      expect(result2.errorMessage, equals(result1.errorMessage));
    });

    test('incrementGeneration invalidates previous cache', () {
      final loader = CameraSnapshotLoader(api: api);
      final gen0 = loader.sourceGeneration;
      loader.incrementGeneration();
      expect(loader.sourceGeneration, equals(gen0 + 1));
      expect(loader.getCachedSnapshot(1), isNull);
    });

    test('clearCache clears queue and cache cleanly', () {
      final loader = CameraSnapshotLoader(api: api);
      loader.clearCache();
      expect(loader.getCachedSnapshot(1), isNull);
      expect(loader.currentCacheBytes, equals(0));
    });

    test('loadSnapshot with fake client caches response and tracks byte size accurately', () async {
      final fakeImage1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]); // 10 bytes
      final client = _FakeHttpClient((request) async {
        return http.Response.bytes(fakeImage1, 200);
      });

      final loader = CameraSnapshotLoader(api: api, httpClient: client);
      final res = await loader.loadSnapshot(1);
      expect(res.isSuccess, isTrue);
      expect(res.bytes?.lengthInBytes, equals(10));
      expect(loader.cacheCount, equals(1));
      expect(loader.currentCacheBytes, equals(10));

      // Refresh with same key but different byte size (20 bytes)
      final fakeImage2 = Uint8List.fromList(List.filled(20, 1));
      final client2 = _FakeHttpClient((request) async {
        return http.Response.bytes(fakeImage2, 200);
      });
      final loader2 = CameraSnapshotLoader(api: api, httpClient: client2);
      await loader2.loadSnapshot(1);
      expect(loader2.currentCacheBytes, equals(20));

      // Force refresh on loader2: byte count should be updated without duplicate accumulation
      final resRefresh = await loader2.loadSnapshot(1, forceRefresh: true);
      expect(resRefresh.isSuccess, isTrue);
      expect(loader2.cacheCount, equals(1));
      expect(loader2.currentCacheBytes, equals(20));
    });

    test('loadSnapshot deduplicates in-flight requests for same camera', () async {
      int serverHits = 0;
      final fakeImage = Uint8List.fromList([1, 2, 3, 4]);
      final client = _FakeHttpClient((request) async {
        serverHits++;
        await Future.delayed(const Duration(milliseconds: 20));
        return http.Response.bytes(fakeImage, 200);
      });

      final loader = CameraSnapshotLoader(api: api, httpClient: client);
      final future1 = loader.loadSnapshot(5);
      final future2 = loader.loadSnapshot(5);

      final results = await Future.wait([future1, future2]);
      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect(serverHits, equals(1)); // Only 1 HTTP call made
    });
  });
}
