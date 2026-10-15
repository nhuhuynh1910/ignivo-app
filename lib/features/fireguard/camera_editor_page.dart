import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';

/// Compact mobile form; omitted advanced values are preserved by partial PUT.
class GuardCameraEditor extends StatefulWidget {
  const GuardCameraEditor({super.key, required this.api, this.camera});
  final FireguardApiService api;
  final Map<String, dynamic>? camera;
  @override
  State<GuardCameraEditor> createState() => _GuardCameraEditorState();
}

class _GuardCameraEditorState extends State<GuardCameraEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.camera?['name'] ?? '');
  late final _area = TextEditingController(text: widget.camera?['area'] ?? '');
  late final _source = TextEditingController(
    text: widget.camera?['source'] ?? '',
  );
  late final _fps = TextEditingController(
    text: '${widget.camera?['ai_fps'] ?? 8}',
  );
  late String _type = widget.camera?['source_type'] ?? 'rtsp';
  late bool _enabled = widget.camera?['enabled'] ?? true;
  late bool _detect = widget.camera?['detect_enabled'] ?? true;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _area, _source, _fps]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || !widget.api.canConfigure) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'area': _area.text.trim(),
      'source_type': _type,
      'enabled': _enabled,
      'detect_enabled': _detect,
      'ai_fps': double.parse(_fps.text.trim()),
      // Do not echo a masked password if the source is unchanged.
      if (widget.camera == null ||
          _source.text.trim() != widget.camera!['source'])
        'source': _source.text.trim(),
    };
    final ok = await widget.api.saveCamera(
      data,
      id: widget.camera?['id'] as int?,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = widget.api.lastError ?? 'Không lưu được camera.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.camera == null ? 'Thêm camera' : 'Sửa camera'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Camera được kết nối và xử lý trên Pi. Thay đổi sẽ áp dụng ngay sau khi lưu.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tên camera'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập tên camera' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _area,
            enabled: !_saving,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Khu vực',
              helperText: 'Được đọc trong cuộc gọi cảnh báo',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Loại nguồn'),
            items: const [
              DropdownMenuItem(value: 'rtsp', child: Text('Camera IP · RTSP')),
              DropdownMenuItem(value: 'usb', child: Text('Camera USB trên Pi')),
              DropdownMenuItem(value: 'mjpeg', child: Text('Luồng MJPEG')),
              DropdownMenuItem(value: 'snapshot', child: Text('Ảnh HTTP')),
            ],
            onChanged: _saving ? null : (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _source,
            enabled: !_saving,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Đường dẫn nguồn',
              hintText: _type == 'usb' ? '/dev/video0' : 'rtsp://...',
              helperText: widget.camera == null
                  ? null
                  : 'Giữ nguyên đường dẫn để giữ mật khẩu đã lưu.',
              helperMaxLines: 2,
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Nhập nguồn camera';
              final prefixes = _type == 'usb'
                  ? ['/dev/']
                  : _type == 'rtsp'
                  ? ['rtsp://', 'rtsps://']
                  : ['http://', 'https://'];
              if (!prefixes.any(value.startsWith)) {
                return 'Nguồn phải bắt đầu bằng ${prefixes.join(' hoặc ')}';
              }
              if (value.contains('***') && value != widget.camera?['source']) {
                return 'Nhập URL đầy đủ khi thay đổi nguồn';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fps,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'FPS mục tiêu của AI',
              helperText: 'Từ 0.5 đến 30; khác với FPS thực tế',
            ),
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              return n == null || !n.isFinite || n < .5 || n > 30
                  ? 'Nhập số từ 0.5 đến 30'
                  : null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bật camera'),
            value: _enabled,
            onChanged: _saving ? null : (v) => setState(() => _enabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chạy AI nhận diện'),
            subtitle: const Text('Tắt AI chỉ còn xem hình từ camera này.'),
            value: _detect,
            onChanged: _saving ? null : (v) => setState(() => _detect = v),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || !widget.api.canConfigure ? null : _save,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu camera'),
          ),
        ],
      ),
    ),
  );
}
