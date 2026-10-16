import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/pi_connection_profile.dart';
import '../../core/services/fireeye_api_service.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/messaging_service.dart';
import '../fireguard/fireguard_page.dart';
import 'pi_setup_page.dart';

enum ConnectionFlowState {
  loadingProfile,
  needsSetup,
  signedOut,
  authenticating,
  checkingMonitor,
  ready,
  degraded,
}

class EdgeConnectionPage extends StatefulWidget {
  const EdgeConnectionPage({
    super.key,
    this.api,
    this.autoNavigate = false,
  });

  final FireeyeApiService? api;
  final bool autoNavigate;

  @override
  State<EdgeConnectionPage> createState() => _EdgeConnectionPageState();
}

class _EdgeConnectionPageState extends State<EdgeConnectionPage> {
  late final _eye = widget.api ?? FireeyeApiService.instance;
  late final _guard = _eye.fireguard;

  final _eyeUrl = TextEditingController();
  final _guardUrl = TextEditingController();
  final _phone = TextEditingController();
  final _secret = TextEditingController();
  final _systemSecret = TextEditingController();
  final _token = TextEditingController();

  PiConnectionProfile _profile = PiConnectionProfile.createDefault();
  ConnectionFlowState _flowState = ConnectionFlowState.loadingProfile;

  bool _obscureSecret = true;
  bool _obscureSystemSecret = true;
  bool _busy = true;
  bool _navigating = false;
  String? _message;

  bool get _authenticated =>
      _flowState == ConnectionFlowState.ready ||
      _flowState == ConnectionFlowState.degraded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _profile = await PiConnectionProfile.load(prefs);

      await _eye.init();
      if (!mounted) return;

      _eyeUrl.text = _profile.eyeUrl;
      _guardUrl.text = _profile.guardUrl;

      if (_eye.authenticated && _guard.currentUser != null) {
        _flowState = ConnectionFlowState.ready;
      } else if (_eye.authenticated) {
        _flowState = ConnectionFlowState.degraded;
      } else {
        _flowState = ConnectionFlowState.signedOut;
      }
    } catch (e) {
      _message = '$e';
      _flowState = ConnectionFlowState.signedOut;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _eyeUrl,
      _guardUrl,
      _phone,
      _secret,
      _systemSecret,
      _token,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openSetup() async {
    final updated = await Navigator.push<PiConnectionProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => PiSetupPage(initialProfile: _profile),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _profile = updated;
        _eyeUrl.text = updated.eyeUrl;
        _guardUrl.text = updated.guardUrl;
        _message = 'Đã cập nhật kết nối: ${updated.piHost}';
      });
    }
  }

  Future<void> _checkMonitorOnly() async {
    setState(() {
      _busy = true;
      _flowState = ConnectionFlowState.checkingMonitor;
      _message = null;
    });

    try {
      await _guard.getCurrentUser();
      if (mounted) {
        setState(() {
          _flowState = ConnectionFlowState.ready;
          _message =
              'FireEye: đã đăng nhập (${_eye.currentUser?['role'] ?? 'người dùng'}).\nFireGuard: đã xác thực.';
        });
        if (widget.autoNavigate && !_navigating) {
          _openDashboard();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _flowState = ConnectionFlowState.degraded;
          _message =
              'FireEye: đã đăng nhập (${_eye.currentUser?['role'] ?? 'người dùng'}).\nFireGuard chưa sẵn sàng: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect({bool withToken = false}) async {
    setState(() {
      _busy = true;
      _message = null;
      _flowState = ConnectionFlowState.authenticating;
    });

    try {
      final eyeUrl = FireguardApiService.normalizeBaseUrl(_eyeUrl.text);
      final guardUrl = FireguardApiService.normalizeBaseUrl(_guardUrl.text);
      if (eyeUrl == guardUrl) {
        throw const FormatException(
          'FireEye dùng cổng 8000 và FireGuard dùng cổng 8080. Nhập hai địa chỉ dịch vụ khác nhau.',
        );
      }
      if (withToken
          ? _token.text.trim().isEmpty
          : (_phone.text.trim().isEmpty ||
                _secret.text.isEmpty ||
                _systemSecret.text.isEmpty)) {
        throw const FormatException(
          'Điền đầy đủ thông tin đăng nhập hoặc access token FireEye.',
        );
      }

      // Persist profile if URLs changed
      if (eyeUrl != _profile.eyeUrl || guardUrl != _profile.guardUrl) {
        _profile = PiConnectionProfile.fromCustomUrls(
          systemName: _profile.systemName,
          eyeUrl: eyeUrl,
          guardUrl: guardUrl,
        );
        final prefs = await SharedPreferences.getInstance();
        await _profile.save(prefs);
      }

      await _guard.setBaseUrl(guardUrl);
      await _eye.configure(eyeUrl);

      if (withToken) {
        await _eye.useToken(_token.text.trim());
      } else {
        await _eye.login(
          phoneNumber: _phone.text.trim(),
          secretKey: _secret.text,
          systemSecretKey: _systemSecret.text,
        );
      }

      // Clear credentials from memory immediately after login attempt
      _secret.clear();
      _systemSecret.clear();
      _token.clear();

      setState(() => _flowState = ConnectionFlowState.checkingMonitor);

      String guardMessage;
      bool guardOk = false;
      try {
        await _guard.getCurrentUser();
        guardMessage = 'FireGuard: đã xác thực.';
        guardOk = true;
      } catch (e) {
        guardMessage = 'FireGuard chưa sẵn sàng: $e';
        guardOk = false;
      }

      if (!mounted) return;

      setState(() {
        if (_eye.authenticated && guardOk) {
          _flowState = ConnectionFlowState.ready;
          _message =
              'FireEye: đã đăng nhập (${_eye.currentUser?['role'] ?? 'người dùng'}).\n$guardMessage';
        } else if (_eye.authenticated) {
          _flowState = ConnectionFlowState.degraded;
          _message =
              'FireEye: đã đăng nhập (${_eye.currentUser?['role'] ?? 'người dùng'}).\n$guardMessage';
        } else {
          _flowState = ConnectionFlowState.signedOut;
          _message =
              'Phiên đăng nhập bị từ chối. Kiểm tra hai dịch vụ có thuộc cùng hệ thống FireEye không.';
        }
      });

      if (_flowState == ConnectionFlowState.ready &&
          widget.autoNavigate &&
          !_navigating) {
        _openDashboard();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _flowState = ConnectionFlowState.signedOut;
          _message = e is FormatException ? e.message : '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDashboard() async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FireguardPage(api: _guard, eye: _eye),
        ),
      );
    } finally {
      _navigating = false;
      if (mounted) {
        setState(() {
          if (_eye.authenticated && _guard.currentUser != null) {
            _flowState = ConnectionFlowState.ready;
          } else if (_eye.authenticated) {
            _flowState = ConnectionFlowState.degraded;
          } else {
            _flowState = ConnectionFlowState.signedOut;
          }
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await MessagingService(api: _guard).unregisterDevice();
    } catch (_) {
      /* Outage or timeout does not block local session logout */
    }
    try {
      await _eye.logout();
    } catch (_) {
      /* Session cleared locally regardless */
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _flowState = ConnectionFlowState.signedOut;
        _message = 'Đã đăng xuất hệ thống.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kết nối hệ thống Pi'),
      actions: [
        IconButton(
          tooltip: 'Thiết lập địa chỉ Pi',
          onPressed: _busy ? null : _openSetup,
          icon: const Icon(Icons.settings_ethernet),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.developer_board,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile.systemName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Địa chỉ: ${_profile.piHost}${_profile.isCustomAdvanced ? ' (URL tùy chỉnh)' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _openSetup,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Sửa'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Một tài khoản cho toàn bộ hệ thống',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'FireEye xác thực tài khoản. FireGuard phụ trách camera, phát hiện lửa/khói, phân tích Gemini, gọi Stringee và cảnh báo trực tiếp.',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('fireeye-url'),
          controller: _eyeUrl,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() => _flowState = ConnectionFlowState.signedOut),
          decoration: const InputDecoration(
            labelText: 'FireEye — xác thực (8000)',
            hintText: 'http://100.95.189.60:8000',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('fireguard-url'),
          controller: _guardUrl,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() => _flowState = ConnectionFlowState.signedOut),
          decoration: const InputDecoration(
            labelText: 'FireGuard — giám sát (8080)',
            hintText: 'http://100.95.189.60:8080',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('phone'),
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại FireEye',
            prefixIcon: Icon(Icons.phone),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('secret'),
          controller: _secret,
          enabled: !_busy,
          obscureText: _obscureSecret,
          decoration: InputDecoration(
            labelText: 'Mật khẩu FireEye',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
              tooltip: _obscureSecret ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('system-secret'),
          controller: _systemSecret,
          enabled: !_busy,
          obscureText: _obscureSystemSecret,
          decoration: InputDecoration(
            labelText: 'Mã khoá hệ thống',
            prefixIcon: const Icon(Icons.vpn_key),
            suffixIcon: IconButton(
              icon: Icon(_obscureSystemSecret ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureSystemSecret = !_obscureSystemSecret),
              tooltip: _obscureSystemSecret ? 'Hiện mã khoá' : 'Ẩn mã khoá',
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _connect,
          icon: const Icon(Icons.login),
          label: const Text('Đăng nhập hệ thống'),
        ),
        ExpansionTile(
          key: const ValueKey('edge_connection_token_tile'),
          title: const Text('Đã có token FireEye'),
          children: [
            TextField(
              controller: _token,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Access token'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _connect(withToken: true),
              child: const Text('Kiểm tra và sử dụng token'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Lưu ý: Dán token chỉ có hiệu lực cho phiên hiện tại và không tự động làm mới khi hết hạn.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _message!,
              style: TextStyle(
                color: _flowState == ConnectionFlowState.degraded
                    ? Colors.orange.shade900
                    : null,
                fontWeight: _flowState == ConnectionFlowState.degraded
                    ? FontWeight.bold
                    : null,
              ),
            ),
          ),
        if (_flowState == ConnectionFlowState.degraded) ...[
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Đã đăng nhập — chưa kết nối giám sát',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dịch vụ xác thực FireEye hoạt động bình thường, nhưng chưa kết nối được dịch vụ FireGuard (:8080). Bạn không cần nhập lại mật khẩu khi dịch vụ khởi động xong.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _checkMonitorOnly,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại kết nối giám sát'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_flowState == ConnectionFlowState.ready) ...[
          FilledButton.icon(
            icon: const Icon(Icons.dashboard),
            label: const Text('Mở tổng quan hệ thống'),
            onPressed: _busy ? null : _openDashboard,
          ),
          const SizedBox(height: 8),
        ],
        if (_authenticated) ...[
          TextButton.icon(
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất hệ thống'),
          ),
        ],
      ],
    ),
  );
}
