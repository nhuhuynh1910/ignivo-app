import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';

class GuardEscalationPage extends StatefulWidget {
  const GuardEscalationPage({super.key, required this.api});
  final FireguardApiService api;
  @override
  State<GuardEscalationPage> createState() => _GuardEscalationPageState();
}

class _GuardEscalationPageState extends State<GuardEscalationPage> {
  final _form = GlobalKey<FormState>();
  final _delay = TextEditingController(),
      _retry = TextEditingController(),
      _rounds = TextEditingController();
  Map<String, dynamic>? _values;
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _delay.dispose();
    _retry.dispose();
    _rounds.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await widget.api.getEscalationSettings();
      if (!mounted) return;
      _values = v;
      _delay.text = '${v['fire_dept_delay_s']}';
      _retry.text = '${v['retry_after_s']}';
      _rounds.text = '${v['max_rounds']}';
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!widget.api.canConfigure || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // PUT replaces this settings group. Read again to preserve voice/speed/
      // loop and any fields deliberately left out of the mobile form.
      final current = await widget.api.getEscalationSettings();
      final data = {
        ...current,
        for (final key in [
          'call_family',
          'call_fire_dept',
          'trigger_on_smoke',
          'fire_dept_min_severity',
        ])
          key: _values![key],
        'fire_dept_delay_s': int.parse(_delay.text),
        'retry_after_s': int.parse(_retry.text),
        'max_rounds': int.parse(_rounds.text),
      };
      final ok = await widget.api.updateEscalationSettings(data);
      if (!mounted) return;
      if (!ok) {
        throw FireguardException(
          widget.api.lastError ?? 'Không lưu được quy tắc.',
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu quy tắc gọi điện.')));
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _number(
    String label,
    TextEditingController controller,
    int min,
    int max,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      enabled: widget.api.canConfigure && !_saving,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: '$min–$max'),
      validator: (v) {
        final n = int.tryParse(v?.trim() ?? '');
        return n == null || n < min || n > max
            ? 'Nhập số nguyên từ $min đến $max'
            : null;
      },
    ),
  );
  Widget _toggle(String key, String title) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: _values![key] == true,
    onChanged: widget.api.canConfigure && !_saving
        ? (v) => setState(() => _values![key] = v)
        : null,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quy tắc gọi điện')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (_values == null)
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (_values != null) ...[
                  const Text(
                    'FireGuard áp dụng các quy tắc này khi xử lý sự cố. Lưu cấu hình không tạo cuộc gọi thử.',
                  ),
                  const SizedBox(height: 12),
                  _toggle('call_family', 'Gọi người thân'),
                  _toggle('call_fire_dept', 'Gọi PCCC / bảo vệ'),
                  _toggle('trigger_on_smoke', 'Xử lý cảnh báo khói'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _values!['fire_dept_min_severity'],
                    decoration: const InputDecoration(
                      labelText: 'Gọi PCCC ngay từ mức',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                      DropdownMenuItem(
                        value: 'critical',
                        child: Text('Nghiêm trọng'),
                      ),
                    ],
                    onChanged: widget.api.canConfigure && !_saving
                        ? (v) => setState(
                            () => _values!['fire_dept_min_severity'] = v,
                          )
                        : null,
                  ),
                  _number(
                    'Chờ xác nhận trước khi gọi PCCC (giây)',
                    _delay,
                    0,
                    1800,
                  ),
                  _number(
                    'Khoảng cách gọi lại người thân (giây)',
                    _retry,
                    30,
                    1800,
                  ),
                  _number('Số vòng gọi tối đa', _rounds, 1, 5),
                  const SizedBox(height: 16),
                  if (widget.api.canConfigure)
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Đang lưu…' : 'Lưu quy tắc'),
                    )
                  else
                    const Text('Chỉ OWNER/ADMIN được sửa cấu hình.'),
                ],
              ],
            ),
          ),
  );
}
