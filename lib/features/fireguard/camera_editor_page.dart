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
  late final _fps = TextEditingController(
    text: '${widget.camera?['ai_fps'] ?? 8}',
  );
  late bool _enabled = widget.camera?['enabled'] ?? true;
  late bool _detect = widget.camera?['detect_enabled'] ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _area, _fps]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.camera == null || !_form.currentState!.validate() || !widget.api.canConfigure) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // Partial update only sends fields configurable on mobile; no raw RTSP or credentials.
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'area': _area.text.trim(),
      'enabled': _enabled,
      'detect_enabled': _detect,
      'ai_fps': double.parse(_fps.text.trim()),
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
          if (widget.camera == null) ...[
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Việc thêm camera mới (RTSP/USB) được thiết lập trực tiếp trên Edge Box hoặc giao diện quản trị hệ thống để bảo đảm an toàn kết nối. Ứng dụng di động chỉ hỗ trợ cấu hình camera đã có.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Card(
              color: Colors.blueGrey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: Colors.black54),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nguồn video và thông tin RTSP được bảo mật trực tiếp trên Edge Box.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _name,
            enabled: !_saving && widget.camera != null,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tên camera'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập tên camera' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _area,
            enabled: !_saving && widget.camera != null,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Khu vực',
              helperText: 'Được đọc trong cuộc gọi cảnh báo',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fps,
            enabled: !_saving && widget.camera != null,
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
            onChanged: _saving || widget.camera == null ? null : (v) => setState(() => _enabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chạy AI nhận diện'),
            subtitle: const Text('Tắt AI chỉ còn xem hình từ camera này.'),
            value: _detect,
            onChanged: _saving || widget.camera == null ? null : (v) => setState(() => _detect = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || !widget.api.canConfigure || widget.camera == null ? null : _save,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu camera'),
          ),
        ],
      ),
    ),
  );
}
