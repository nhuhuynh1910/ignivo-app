import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/pi_connection_profile.dart';
import '../../core/services/fireguard_api_service.dart';

class PiSetupPage extends StatefulWidget {
  const PiSetupPage({super.key, this.initialProfile});

  final PiConnectionProfile? initialProfile;

  @override
  State<PiSetupPage> createState() => _PiSetupPageState();
}

class _PiSetupPageState extends State<PiSetupPage> {
  final _systemName = TextEditingController();
  final _piHost = TextEditingController();
  final _eyeUrl = TextEditingController();
  final _guardUrl = TextEditingController();

  bool _isAdvanced = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile ?? PiConnectionProfile.createDefault();
    _systemName.text = p.systemName;
    _piHost.text = p.piHost;
    _eyeUrl.text = p.eyeUrl;
    _guardUrl.text = p.guardUrl;
    _isAdvanced = p.isCustomAdvanced;
  }

  @override
  void dispose() {
    _systemName.dispose();
    _piHost.dispose();
    _eyeUrl.dispose();
    _guardUrl.dispose();
    super.dispose();
  }

  void _onHostChanged(String host) {
    if (!_isAdvanced) {
      final p = PiConnectionProfile.fromHost(host, systemName: _systemName.text);
      _eyeUrl.text = p.eyeUrl;
      _guardUrl.text = p.guardUrl;
    }
  }

  void _applyPreset(String host) {
    _piHost.text = host;
    final p = PiConnectionProfile.fromHost(host, systemName: _systemName.text);
    _eyeUrl.text = p.eyeUrl;
    _guardUrl.text = p.guardUrl;
    _isAdvanced = false;
    setState(() => _error = null);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      PiConnectionProfile profile;
      if (_isAdvanced) {
        final eyeUrl = FireguardApiService.normalizeBaseUrl(_eyeUrl.text);
        final guardUrl = FireguardApiService.normalizeBaseUrl(_guardUrl.text);
        if (eyeUrl == guardUrl) {
          throw const FormatException(
            'FireEye (cổng 8000) và FireGuard (cổng 8080) phải có cổng hoặc địa chỉ khác nhau.',
          );
        }
        profile = PiConnectionProfile.fromCustomUrls(
          systemName: _systemName.text,
          eyeUrl: eyeUrl,
          guardUrl: guardUrl,
        );
      } else {
        if (_piHost.text.trim().isEmpty) {
          throw const FormatException('Vui lòng nhập địa chỉ IP hoặc tên miền của Pi.');
        }
        profile = PiConnectionProfile.fromHost(
          _piHost.text,
          systemName: _systemName.text,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await profile.save(prefs);

      if (mounted) {
        Navigator.pop(context, profile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FormatException ? e.message : '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thiết lập kết nối Pi'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Một địa chỉ cho toàn bộ hệ thống IGNIVO',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hệ thống trên Raspberry Pi tích hợp xác thực tài khoản (:8000) và hệ thống giám sát AI, camera, cảnh báo (:8080). Bạn chỉ cần nhập một địa chỉ duy nhất.',
          style: TextStyle(color: Colors.black87),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('setup-system-name'),
          controller: _systemName,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Tên hệ thống / Địa điểm',
            hintText: 'Hệ thống IGNIVO Pi (hoặc Nhà riêng, Nhà xưởng...)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('setup-pi-host'),
          controller: _piHost,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          onChanged: _onHostChanged,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ Pi (IP Tailscale / LAN)',
            hintText: '100.95.189.60 hoặc 192.168.1.50',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.router),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.lan, size: 18),
              label: const Text('Tailscale 100.95.189.60'),
              onPressed: _busy ? null : () => _applyPreset('100.95.189.60'),
            ),
            ActionChip(
              avatar: const Icon(Icons.computer, size: 18),
              label: const Text('Localhost (127.0.0.1)'),
              onPressed: _busy ? null : () => _applyPreset('127.0.0.1'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          initiallyExpanded: _isAdvanced,
          title: const Text('Kết nối nâng cao (tùy chỉnh URL từng dịch vụ)'),
          subtitle: Text(
            _isAdvanced
                ? 'Đang dùng URL tùy chỉnh'
                : 'Tự động tạo URL (:8000 và :8080)',
            style: const TextStyle(fontSize: 12),
          ),
          onExpansionChanged: (exp) {
            setState(() => _isAdvanced = exp);
          },
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Dành cho trường hợp dịch vụ chạy trên các port khác hoặc qua reverse proxy HTTPS riêng.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                key: const Key('setup-fireeye-url'),
                controller: _eyeUrl,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() => _isAdvanced = true),
                decoration: const InputDecoration(
                  labelText: 'FireEye URL (xác thực :8000)',
                  hintText: 'http://100.95.189.60:8000',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                key: const Key('setup-fireguard-url'),
                controller: _guardUrl,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() => _isAdvanced = true),
                decoration: const InputDecoration(
                  labelText: 'FireGuard URL (giám sát :8080)',
                  hintText: 'http://100.95.189.60:8080',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.check),
          label: const Text('Lưu cấu hình kết nối'),
        ),
      ],
    ),
  );
}
