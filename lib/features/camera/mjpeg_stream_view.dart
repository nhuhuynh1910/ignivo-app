import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/app_theme.dart';

/// Widget phát luồng video MJPEG thời gian thực từ FireGuard (kèm Bounding Box AI)
class MjpegStreamView extends StatefulWidget {
  const MjpegStreamView({
    super.key,
    required this.streamUrl,
    this.width = double.infinity,
    this.height = 220,
    this.fit = BoxFit.contain,
    this.showStats = true,
    this.requestHeaders,
    this.httpClient,
  });

  final String streamUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final bool showStats;
  final Map<String, String>? requestHeaders;
  final http.Client? httpClient;

  @override
  State<MjpegStreamView> createState() => _MjpegStreamViewState();
}

class _MjpegStreamViewState extends State<MjpegStreamView> {
  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;

  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _isPaused = false;
  String? _errorMessage;
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  double _fps = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl ||
        oldWidget.requestHeaders?['Authorization'] !=
            widget.requestHeaders?['Authorization']) {
      _isPaused = false;
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream({bool keepFrame = false}) {
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    if (!keepFrame) {
      _currentFrame = null;
    }
  }

  void _pauseStream() {
    _stopStream(keepFrame: true);
    if (mounted) {
      setState(() {
        _isPaused = true;
        _isLoading = false;
      });
    }
  }

  void _resumeStream() {
    if (mounted) {
      setState(() => _isPaused = false);
    }
    _startStream();
  }

  Future<void> _startStream() async {
    final generation = ++_generation;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _frameCount = 0;
      _fps = 0;
      _lastFpsTime = DateTime.now();
    });

    _client = widget.httpClient ?? http.Client();
    final request = http.Request('GET', Uri.parse(widget.streamUrl));
    request.headers.addAll(
      widget.requestHeaders ??
          FireguardApiService.instance.headersForUrl(widget.streamUrl),
    );
    request.headers['Accept'] = 'multipart/x-mixed-replace';

    try {
      final response = await _client!
          .send(request)
          .timeout(const Duration(seconds: 10));
      if (!mounted || generation != _generation) return;

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = response.statusCode == 401
              ? 'Phiên đã hết hạn. Quay lại Kết nối hệ thống Pi để đăng nhập.'
              : 'Lỗi kết nối stream: HTTP ${response.statusCode}';
        });
        _client?.close();
        return;
      }

      final buffer = BytesBuilder(copy: false);

      _subscription = response.stream
          .timeout(const Duration(seconds: 15))
          .listen(
            (chunk) {
              if (!mounted || generation != _generation) return;
              buffer.add(chunk);
              // Bound memory if the server sends malformed data instead of JPEGs.
              if (buffer.length > 8 * 1024 * 1024) {
                buffer.clear();
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Khung hình vượt quá giới hạn 8 MB.';
                });
                _stopStream();
                return;
              }
              var bytes = buffer.toBytes();
              while (bytes.length > 3) {
                // Tìm mốc JPEG SOI (0xFF, 0xD8) và EOI (0xFF, 0xD9)
                int start = -1;
                for (int i = 0; i < bytes.length - 1; i++) {
                  if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
                    start = i;
                    break;
                  }
                }

                bool found = false;
                if (start != -1) {
                  for (int i = start + 2; i < bytes.length - 1; i++) {
                    if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
                      final end = i + 2;
                      final frameBytes = Uint8List.sublistView(
                        bytes,
                        start,
                        end,
                      );

                      buffer.clear();
                      if (end < bytes.length) {
                        buffer.add(Uint8List.sublistView(bytes, end));
                      }

                      _onNewFrame(frameBytes);
                      found = true;
                      bytes = buffer.toBytes();
                      break;
                    }
                  }
                }
                if (!found) break;
              }
            },
            onError: (err) {
              if (!mounted || generation != _generation) return;
              setState(() {
                _errorMessage = 'Mất kết nối luồng: $err';
                _isLoading = false;
              });
              _stopStream();
            },
            onDone: () {
              if (!mounted || generation != _generation) return;
              setState(() {
                _isLoading = false;
                _errorMessage = 'Luồng camera đã đóng. Bấm Thử lại để kết nối.';
              });
              _stopStream();
            },
            cancelOnError: true,
          );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể kết nối luồng camera: $e';
      });
      _stopStream();
    }
  }

  void _onNewFrame(Uint8List frameBytes) {
    if (!mounted) return;

    _frameCount++;
    final now = DateTime.now();
    final diff = now.difference(_lastFpsTime).inMilliseconds;
    if (diff >= 1000) {
      _fps = (_frameCount * 1000) / diff;
      _frameCount = 0;
      _lastFpsTime = now;
    }

    setState(() {
      _currentFrame = frameBytes;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Frame hình ảnh
            if (_currentFrame != null)
              Image.memory(
                _currentFrame!,
                width: double.infinity,
                height: double.infinity,
                fit: widget.fit,
                gaplessPlayback: true,
              ),

            // Loading state
            if (_isLoading)
              Container(
                color: Colors.black87,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Đang kết nối camera...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Error state
            if (_errorMessage != null)
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      color: AppColors.danger,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        _stopStream();
                        _startStream();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Thử lại',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Overlay Paused Banner
            if (_isPaused)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle_filled, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Đã tạm dừng phát luồng',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top-right Pause / Resume button
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: _isPaused ? _resumeStream : _pauseStream,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPaused ? 'Tiếp tục' : 'Tạm dừng',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Overlay Badge AI Live & FPS
            if (_currentFrame != null &&
                _errorMessage == null &&
                !_isPaused &&
                widget.showStats)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE AI • ${_fps.toStringAsFixed(1)} fps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
