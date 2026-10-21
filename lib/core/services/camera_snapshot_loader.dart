import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'fireguard_api_service.dart';

/// Trạng thái hoặc kết quả tải ảnh snapshot từ Pi
class SnapshotResult {
  const SnapshotResult({
    this.bytes,
    this.statusCode,
    this.errorMessage,
    this.fetchedAt,
  });

  final Uint8List? bytes;
  final int? statusCode;
  final String? errorMessage;
  final DateTime? fetchedAt;

  bool get isSuccess => bytes != null && bytes!.isNotEmpty;
  bool get isEngineStopped => statusCode == 409;
  bool get isNoFrame => statusCode == 503;
}

/// Entry trong LRU cache bộ nhớ
class _CacheEntry {
  _CacheEntry({
    required this.bytes,
    required this.fetchedAt,
  }) : sizeInBytes = bytes.lengthInBytes;

  final Uint8List bytes;
  final DateTime fetchedAt;
  final int sizeInBytes;
}

class _FailureEntry {
  _FailureEntry({
    required this.result,
    required this.failedAt,
  });

  final SnapshotResult result;
  final DateTime failedAt;
}

/// Lớp điều phối tải ảnh snapshot camera từ Raspberry Pi Edge Box
///
/// Tuân thủ nghiêm ngặt các tiêu chuẩn kỹ thuật trong STITCH_UI_REDESIGN_PLAN.md (Bản 3):
/// 1. Tối đa 2 request đang chạy đồng thời (maxConcurrent = 2).
/// 2. Hàng đợi tải ảnh, chống gửi request trùng lặp (in-flight deduplication).
/// 3. Giới hạn bộ nhớ đệm RAM kép: tối đa 20 ảnh VÀ 16 MiB byte JPEG thô.
/// 4. Hủy/bỏ qua kết quả khi card rời màn hình hoặc đổi phiên/nguồn.
/// 5. Không lộ Bearer token trên query string (dùng Authorization Header).
class CameraSnapshotLoader {
  CameraSnapshotLoader({
    required this.api,
    http.Client? httpClient,
    this.maxConcurrent = 2,
    this.maxItems = 20,
    this.maxBytes = 16 * 1024 * 1024, // 16 MiB
  })  : _client = httpClient ?? api.client,
        _isCustomClient = httpClient != null;

  final FireguardApiService api;
  final http.Client _client;
  final bool _isCustomClient;
  final int maxConcurrent;
  final int maxItems;
  final int maxBytes;

  int _sourceGeneration = 0;
  int get sourceGeneration => _sourceGeneration;
  int get currentCacheBytes => _currentCacheBytes;
  int get cacheCount => _cache.length;

  /// Tăng generation nguồn khi có cấu hình camera thay đổi để loại bỏ cache cũ
  void incrementGeneration() {
    _sourceGeneration++;
    _cache.clear();
    _currentCacheBytes = 0;
    _failureCache.clear();
  }

  // LRU cache: LinkedHashMap lưu theo thứ tự truy cập gần nhất
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  int _currentCacheBytes = 0;

  // Failure cache để chống spam request khi camera offline, engine tắt (409) hoặc chưa có frame (503)
  final Map<String, _FailureEntry> _failureCache = {};
  Duration failureCooldown = const Duration(seconds: 15);

  // Quản lý request đang chạy và hàng đợi
  int _runningRequests = 0;
  int get runningRequests => _runningRequests;
  final List<_SnapshotJob> _queue = [];
  final Map<String, Future<SnapshotResult>> _inFlight = {};

  String _buildCacheKey(int cameraId) {
    return '${api.baseUrl}_rev${api.sessionRevision}_cam${cameraId}_gen$_sourceGeneration';
  }

  /// Lấy ảnh từ bộ nhớ đệm nếu có
  SnapshotResult? getCachedSnapshot(int cameraId) {
    final key = _buildCacheKey(cameraId);
    final entry = _cache[key];
    if (entry != null) {
      // Đưa lên cuối danh sách LRU (mới dùng nhất)
      _cache.remove(key);
      _cache[key] = entry;
      return SnapshotResult(
        bytes: entry.bytes,
        statusCode: 200,
        fetchedAt: entry.fetchedAt,
      );
    }
    return null;
  }

  /// Yêu cầu tải ảnh snapshot cho camera
  Future<SnapshotResult> loadSnapshot(
    int cameraId, {
    bool forceRefresh = false,
  }) async {
    final key = _buildCacheKey(cameraId);

    if (!forceRefresh) {
      final cached = getCachedSnapshot(cameraId);
      if (cached != null) return cached;

      // Kiểm tra failure cache với cooldown
      final failure = _failureCache[key];
      if (failure != null) {
        if (DateTime.now().difference(failure.failedAt) < failureCooldown) {
          return failure.result;
        } else {
          _failureCache.remove(key);
        }
      }
    }

    // Nếu đang có request cho cùng key, tái sử dụng Future
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final completer = Completer<SnapshotResult>();
    final job = _SnapshotJob(
      cameraId: cameraId,
      key: key,
      completer: completer,
      generation: _sourceGeneration,
      sessionRevision: api.sessionRevision,
      baseUrl: api.baseUrl,
    );

    _inFlight[key] = completer.future;
    _queue.add(job);
    _processQueue();

    return completer.future;
  }

  void _processQueue() {
    if (_queue.isEmpty || _runningRequests >= maxConcurrent) return;

    final job = _queue.removeAt(0);

    // Kiểm tra xem job có còn đúng phiên và nguồn không
    if (job.baseUrl != api.baseUrl ||
        job.sessionRevision != api.sessionRevision ||
        job.generation != _sourceGeneration) {
      job.completer.complete(
        const SnapshotResult(
          errorMessage: 'Phiên kết nối hoặc cấu hình đã thay đổi.',
        ),
      );
      _inFlight.remove(job.key);
      _processQueue();
      return;
    }

    _runningRequests++;
    _fetchDirect(job).whenComplete(() {
      _runningRequests--;
      _inFlight.remove(job.key);
      _processQueue();
    });
  }

  Future<void> _fetchDirect(_SnapshotJob job) async {
    final snapshotUrl = api.getSnapshotUrl(job.cameraId);
    final uri = Uri.tryParse(snapshotUrl);

    if (uri == null) {
      job.completer.complete(
        const SnapshotResult(errorMessage: 'URL snapshot không hợp lệ.'),
      );
      return;
    }

    try {
      final headers = api.headersForUrl(snapshotUrl);
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));

      // Kiểm tra lại tính hợp lệ sau khi nhận HTTP response
      if (job.baseUrl != api.baseUrl ||
          job.sessionRevision != api.sessionRevision ||
          job.generation != _sourceGeneration) {
        job.completer.complete(
          const SnapshotResult(errorMessage: 'Response bị hủy do đổi phiên.'),
        );
        return;
      }

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        final now = DateTime.now();

        _putIntoCache(job.key, bytes, now);

        job.completer.complete(
          SnapshotResult(
            bytes: bytes,
            statusCode: 200,
            fetchedAt: now,
          ),
        );
      } else {
        final failureResult = SnapshotResult(
          statusCode: response.statusCode,
          errorMessage: response.statusCode == 409
              ? 'Vision Engine đang tắt (409)'
              : response.statusCode == 503
              ? 'Camera chưa có khung hình (503)'
              : 'Lỗi tải ảnh (${response.statusCode})',
        );
        _failureCache[job.key] = _FailureEntry(
          result: failureResult,
          failedAt: DateTime.now(),
        );
        job.completer.complete(failureResult);
      }
    } catch (e) {
      final failureResult = SnapshotResult(
        errorMessage: 'Không thể kết nối tải ảnh: $e',
      );
      _failureCache[job.key] = _FailureEntry(
        result: failureResult,
        failedAt: DateTime.now(),
      );
      job.completer.complete(failureResult);
    }
  }

  void _putIntoCache(String key, Uint8List bytes, DateTime fetchedAt) {
    final size = bytes.lengthInBytes;

    // Nếu kích thước 1 ảnh vượt quá maxBytes, không lưu vào cache
    if (size > maxBytes) return;

    // Nếu key đã tồn tại trong cache (refresh cùng key), loại bỏ entry cũ trước và trừ byte cũ
    final existing = _cache.remove(key);
    if (existing != null) {
      _currentCacheBytes -= existing.sizeInBytes;
    }

    // Loại bỏ ảnh cũ nhất (LRU) nếu vượt số lượng hoặc số byte
    while ((_cache.length >= maxItems || _currentCacheBytes + size > maxBytes) &&
        _cache.isNotEmpty) {
      final firstKey = _cache.keys.first;
      final removed = _cache.remove(firstKey);
      if (removed != null) {
        _currentCacheBytes -= removed.sizeInBytes;
      }
    }

    _cache[key] = _CacheEntry(bytes: bytes, fetchedAt: fetchedAt);
    _currentCacheBytes += size;
  }

  /// Hủy yêu cầu đang chờ trong hàng đợi của một camera cụ thể
  void cancelPending(int cameraId) {
    _queue.removeWhere((job) {
      if (job.cameraId == cameraId) {
        if (!job.completer.isCompleted) {
          job.completer.complete(
            const SnapshotResult(errorMessage: 'Yêu cầu tải ảnh đã bị hủy.'),
          );
        }
        _inFlight.remove(job.key);
        return true;
      }
      return false;
    });
  }

  /// Xóa sạch bộ nhớ đệm (khi logout, đổi Pi)
  void clearCache() {
    _cache.clear();
    _currentCacheBytes = 0;
    _failureCache.clear();
    for (final job in _queue) {
      if (!job.completer.isCompleted) {
        job.completer.complete(
          const SnapshotResult(errorMessage: 'Cache đã bị xóa.'),
        );
      }
    }
    _queue.clear();
    _inFlight.clear();
  }

  /// Giải phóng tài nguyên loader theo phiên
  void dispose() {
    clearCache();
    if (!_isCustomClient) {
      _client.close();
    }
  }
}

class _SnapshotJob {
  _SnapshotJob({
    required this.cameraId,
    required this.key,
    required this.completer,
    required this.generation,
    required this.sessionRevision,
    required this.baseUrl,
  });

  final int cameraId;
  final String key;
  final Completer<SnapshotResult> completer;
  final int generation;
  final int sessionRevision;
  final String baseUrl;
}
