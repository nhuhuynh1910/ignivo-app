import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/pi_connection_profile.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/services/system_session_controller.dart';

class ConnectionSetupPage extends StatefulWidget {
  const ConnectionSetupPage({
    super.key,
    required this.sessionController,
    this.canPop = false,
  });

  final SystemSessionController sessionController;
  final bool canPop;

  @override
  State<ConnectionSetupPage> createState() => _ConnectionSetupPageState();
}

class _ConnectionSetupPageState extends State<ConnectionSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;

  bool _isChecking = false;
  bool? _checkSuccess;
  String? _checkMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.sessionController.profile;
    _nameController = TextEditingController(
      text: profile.systemName.isNotEmpty
          ? profile.systemName
          : PiConnectionProfile.defaultSystemName,
    );
    _urlController = TextEditingController(
      text: profile.guardUrl.isNotEmpty ? profile.guardUrl : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _cleanUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '';
    if (!raw.contains('://')) {
      raw = 'http://$raw';
    }
    return FireguardApiService.normalizeBaseUrl(raw);
  }

  Future<void> _checkConnection() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _checkSuccess = false;
        _checkMessage = 'Vui lòng nhập địa chỉ kết nối trước khi kiểm tra.';
      });
      return;
    }

    final normalized = _cleanUrl(rawUrl);
    setState(() {
      _isChecking = true;
      _checkSuccess = null;
      _checkMessage = null;
    });

    try {
      final probeApi = FireguardApiService();
      await probeApi.setBaseUrl(normalized);
      final ok = await probeApi.checkConnection();
      if (!mounted) return;

      setState(() {
        _isChecking = false;
        _checkSuccess = ok;
        _checkMessage = ok
            ? 'Kết nối thành công tới dịch vụ FireGuard.'
            : 'Không nhận được phản hồi phù hợp từ FireGuard tại địa chỉ này.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _checkSuccess = false;
        _checkMessage = 'Lỗi kết nối: Không thể truy cập địa chỉ được chỉ định.';
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final rawUrl = _urlController.text.trim();
    final normalized = _cleanUrl(rawUrl);
    final systemName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : PiConnectionProfile.defaultSystemName;

    setState(() => _isSaving = true);

    try {
      final newProfile = PiConnectionProfile.fromGuardUrl(
        normalized,
        systemName: systemName,
      );

      final prefs = await SharedPreferences.getInstance();
      await widget.sessionController.updateProfile(newProfile, prefs);

      if (!mounted) return;
      if (widget.canPop && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết nối hệ thống IGNIVO'),
        automaticallyImplyLeading: widget.canPop,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      size: 56,
                      color: Color(0xFFFF5722),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Thiết lập kết nối IGNIVO Pi',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhập tên vị trí và địa chỉ do người cài đặt cung cấp để kết nối đến bộ xử lý FireGuard.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('setup-system-name'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên địa điểm / hệ thống',
                        hintText: 'Ví dụ: Nhà riêng, Xưởng A, Kho hàng...',
                        prefixIcon: Icon(Icons.home_work_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tên nhận diện địa điểm';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('setup-guard-url'),
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ FireGuard',
                        hintText: 'Ví dụ: 100.95.189.60:8080 hoặc http://pi.lan:8080',
                        prefixIcon: Icon(Icons.dns_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập địa chỉ IP hoặc tên miền';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('setup-check-connection-btn'),
                      onPressed: _isChecking ? null : _checkConnection,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check),
                      label: Text(
                        _isChecking ? 'Đang kiểm tra...' : 'Kiểm tra kết nối',
                      ),
                    ),
                    if (_checkMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _checkSuccess == true
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _checkSuccess == true
                                ? Colors.green.shade600
                                : Colors.red.shade400,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _checkSuccess == true
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _checkSuccess == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _checkMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _checkSuccess == true
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('setup-save-btn'),
                      onPressed: _isSaving ? null : _saveAndContinue,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Lưu và tiếp tục',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
