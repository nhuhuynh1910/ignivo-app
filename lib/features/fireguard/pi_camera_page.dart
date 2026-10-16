import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/fireeye_api_service.dart';
import '../../core/services/fireguard_api_service.dart';
import '../camera/mjpeg_stream_view.dart';
import 'people_page.dart';

class PiCameraPage extends StatefulWidget {
  const PiCameraPage({
    super.key,
    required this.eye,
    required this.guard,
    required this.deviceId,
    required this.camera,
  });
  final FireeyeApiService eye;
  final FireguardApiService guard;
  final String deviceId;
  final Map<String, dynamic> camera;
  @override
  State<PiCameraPage> createState() => _PiCameraPageState();
}

class _PiCameraPageState extends State<PiCameraPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _capabilities;
  String? _error;
  String? _direction;
  bool _busy = true, _foreground = true;
  int _preview = 0;
  Future<void> _commands = Future.value();

  bool get _isSameCameraId =>
      _capabilities?['binding']?['guard_device_id'] == widget.deviceId &&
      _capabilities?['binding']?['guard_camera_id'] == widget.camera['id'];

  bool get _isStaleRevision {
    if (!_isSameCameraId) return false;
    final expectedRev = widget.camera['source_revision'];
    final boundRev = _capabilities?['binding']?['source_revision'];
    if (expectedRev != null && boundRev != null && expectedRev != boundRev) {
      return true;
    }
    final status = _capabilities?['status'];
    return status == 'stale' || status == 'invalid';
  }

  bool get _isUnsupported =>
      _capabilities != null &&
      (_capabilities?['status'] == 'unsupported' ||
          _capabilities?['ptz'] == false ||
          _capabilities?['supported'] == false);

  bool get _isOffline =>
      _capabilities != null &&
      (_capabilities?['online'] != true ||
          ['offline', 'unavailable'].contains(_capabilities?['status']));

  bool get _isUnknown =>
      _capabilities != null &&
      ![
        'valid',
        'unbound',
        'stale',
        'invalid',
        'offline',
        'unavailable',
        'unsupported',
      ].contains(_capabilities?['status']);

  bool get _bound {
    if (!_isSameCameraId) return false;
    if (_isStaleRevision) return false;
    final status = _capabilities?['status'];
    if (status != 'valid') return false;
    final expectedRev = widget.camera['source_revision'];
    final boundRev = _capabilities?['binding']?['source_revision'];
    if (expectedRev is String &&
        expectedRev.isNotEmpty &&
        boundRev is String &&
        boundRev.isNotEmpty) {
      return expectedRev == boundRev;
    }
    return false;
  }

  bool get _canControl =>
      _bound &&
      !_isStaleRevision &&
      !_isUnsupported &&
      !_isOffline &&
      !_isUnknown &&
      _capabilities?['ptz'] == true &&
      _capabilities?['online'] == true &&
      widget.eye.canConfigure &&
      _foreground &&
      !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
    if (!_foreground) {
      _stop();
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final String? rev = widget.camera['source_revision']?.toString();
      final value = await widget.eye.getCameraCapabilities(sourceRevision: rev);
      if (mounted) {
        setState(() {
          _capabilities = value;
          _error = null;
          _preview++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _capabilities = null;
          _error = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send(String action, {String stopCode = 'left'}) {
    _commands = _commands.then((_) async {
      try {
        final String? rev = widget.camera['source_revision']?.toString();
        await widget.eye.ptz(
          widget.deviceId,
          widget.camera['id'] as int,
          action,
          stopCode: stopCode,
          sourceRevision: rev,
        );
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
    });
  }

  void _start(String direction) {
    if (_direction != null || !_canControl) {
      return;
    }
    HapticFeedback.selectionClick();
    _direction = direction;
    _send(direction);
  }

  void _stop() {
    final direction = _direction;
    _direction = null;
    if (direction != null) _send('stop', stopCode: direction);
  }

  Future<void> _bind() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận cùng một camera'),
        content: Text(
          'Hai hình xem trước đều là camera "${widget.camera['name']}"? Liên kết này quyết định camera nhận lệnh xoay/zoom.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đúng, liên kết camera'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final String? rev = widget.camera['source_revision']?.toString();
      await widget.eye.bindCamera(
        widget.deviceId,
        widget.camera['id'] as int,
        sourceRevision: rev,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _unbind() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy liên kết PTZ'),
        content: Text(
          'Bạn có chắc chắn muốn hủy liên kết điều khiển PTZ cho camera "${widget.camera['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy liên kết'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.eye.unbindCamera();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Widget _button(String label, String action, IconData icon) => Semantics(
    button: true,
    label: label,
    onTap: () {
      _start(action);
      Future.delayed(const Duration(milliseconds: 350), _stop);
    },
    child: ExcludeSemantics(
      child: GestureDetector(
        onTapDown: (_) => _start(action),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: Container(
          constraints: const BoxConstraints(minWidth: 92, minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), Text(label)],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.camera['name']}'),
      actions: [
        IconButton(
          tooltip: 'Kiểm tra lại',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_isStaleRevision) ...[
          Card(
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.shade400),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cấu hình luồng camera đã thay đổi (source_revision). Vui lòng xác thực hình ảnh và liên kết lại trước khi điều khiển PTZ.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text('Hình từ FireGuard'),
        const SizedBox(height: 8),
        if (_foreground)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (_, box) => MjpegStreamView(
                key: ValueKey('ptz-$_preview'),
                streamUrl: widget.guard.getMjpegStreamUrl(widget.camera['id']),
                requestHeaders: widget.guard.headersForUrl(
                  widget.guard.getMjpegStreamUrl(widget.camera['id']),
                ),
                height: box.maxHeight,
                showStats: false,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          _bound
              ? 'Đã liên kết PTZ với camera này.'
              : _isStaleRevision
              ? 'Liên kết cũ không khớp cấu hình luồng mới.'
              : _isUnsupported
              ? 'Camera này không hỗ trợ điều khiển PTZ.'
              : _isUnknown
              ? 'Chưa xác định được trạng thái điều khiển PTZ của camera.'
              : 'Chưa liên kết PTZ. So sánh hình trước khi xác nhận.',
        ),
        if (!_bound &&
            !_isStaleRevision &&
            !_isUnsupported &&
            !_isUnknown &&
            _capabilities?['ptz'] == true &&
            widget.camera['source_revision'] is String) ...[
          const SizedBox(height: 12),
          const Text('Ảnh từ camera Dahua của FireEye'),
          if (_foreground)
            FireeyeImage(
              key: ValueKey(_preview),
              eye: widget.eye,
              path: '/api/camera/raw-frame',
            ),
          const SizedBox(height: 12),
          if (widget.eye.canConfigure) ...[
            FilledButton.icon(
              onPressed: _busy || _capabilities?['online'] != true
                  ? null
                  : _bind,
              icon: const Icon(Icons.link),
              label: const Text('Liên kết camera này với PTZ'),
            ),
            if (_capabilities?['binding'] != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _busy ? null : _unbind,
                icon: const Icon(Icons.link_off),
                label: const Text('Hủy liên kết hiện tại'),
              ),
            ],
          ],
        ],
        if (_canControl) ...[
          const SizedBox(height: 16),
          const Text(
            'Giữ để di chuyển, thả để gửi lệnh dừng. Khi mất mạng, app không thể xác nhận camera đã dừng.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _button('Trái', 'left', Icons.arrow_back),
              _button('Lên', 'up', Icons.arrow_upward),
              _button('Phải', 'right', Icons.arrow_forward),
              _button('Xuống', 'down', Icons.arrow_downward),
              _button('Phóng to', 'zoom-in', Icons.zoom_in),
              _button('Thu nhỏ', 'zoom-out', Icons.zoom_out),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _stop();
              _send('stop');
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Dừng camera'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _bind,
                  icon: const Icon(Icons.sync),
                  label: const Text('Kiểm tra lại'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _busy ? null : _unbind,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Hủy liên kết'),
                ),
              ),
            ],
          ),
        ],
        if (_capabilities?['online'] == false)
          const Text('Camera FireEye đang mất kết nối. Chưa thể điều khiển.'),
        if (_isUnsupported)
          const Text('Camera này không hỗ trợ điều khiển xoay/zoom (PTZ).'),
        if (!widget.eye.canConfigure)
          const Text('Chỉ chủ sở hữu hoặc quản trị viên được điều khiển PTZ.'),
      ],
    ),
  );
}
