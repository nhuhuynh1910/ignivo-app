import 'package:flutter/material.dart';
import '../../core/services/fireeye_api_service.dart';
import 'people_page.dart';

String eyeEventLabel(dynamic value) =>
    const {
      'KNOWN_PERSON': 'Người đã đăng ký',
      'UNKNOWN_PERSON': 'Chưa đối chiếu được người',
      'FIRE': 'Phát hiện lửa',
      'SMOKE': 'Phát hiện khói',
      'HUMAN': 'Phát hiện người',
    }[value] ??
    '$value';

class EyeEventsPage extends StatefulWidget {
  const EyeEventsPage({super.key, required this.eye});
  final FireeyeApiService eye;
  @override
  State<EyeEventsPage> createState() => _EyeEventsPageState();
}

class _EyeEventsPageState extends State<EyeEventsPage> {
  List<Map<String, dynamic>> _events = [];
  bool _busy = false, _more = true;
  String? _error, _type;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.eye.getEvents(
        beforeId: next && _events.isNotEmpty ? _events.last['id'] as int : null,
        type: _type,
      );
      if (mounted) {
        setState(() {
          _events = next ? [..._events, ...data] : data;
          _more = data.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(eyeEventLabel(event['event_type']))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${event['message'] ?? ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('FireEye · #${event['id']} · ${event['created_at'] ?? ''}'),
              const SizedBox(height: 16),
              if (event['snapshot_path'] is String &&
                  (event['snapshot_path'] as String).isNotEmpty)
                FireeyeImage(eye: widget.eye, path: event['snapshot_path']),
              const SizedBox(height: 16),
              const Text(
                'Đây là sự kiện từ FireEye. Xử lý sự cố cháy và lịch sử gọi tại tab Sự cố của FireGuard.',
              ),
            ],
          ),
        ),
      ),
    );
    try {
      await widget.eye.markEventRead(event['id'] as int);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không đánh dấu đã đọc được: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử FireEye')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sự kiện khuôn mặt, cảm biến và AI của FireEye. Pi hiện lưu lịch sử theo chính sách của dịch vụ.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type ?? '',
            isExpanded: true,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Loại sự kiện',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Tất cả sự kiện', overflow: TextOverflow.ellipsis),
              ),
              for (final type in [
                'KNOWN_PERSON',
                'UNKNOWN_PERSON',
                'FIRE',
                'SMOKE',
                'HUMAN',
              ])
                DropdownMenuItem(
                  value: type,
                  child: Text(
                    eyeEventLabel(type),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    setState(() {
                      _type = v == '' ? null : v;
                      _events = [];
                    });
                    _load();
                  },
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_events.isEmpty && !_busy && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có sự kiện.'),
            ),
          for (final event in _events)
            Card(
              child: ListTile(
                title: Text(eyeEventLabel(event['event_type'])),
                subtitle: Text(
                  '${event['message'] ?? ''}\n${event['created_at'] ?? ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(event),
              ),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null || (_more && _events.isNotEmpty))
            TextButton(
              onPressed: _busy ? null : () => _load(next: _error == null),
              child: Text(_error == null ? 'Tải thêm' : 'Thử lại'),
            ),
        ],
      ),
    ),
  );
}
