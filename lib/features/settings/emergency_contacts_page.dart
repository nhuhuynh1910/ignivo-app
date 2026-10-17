import 'package:flutter/material.dart';
import '../../widgets/ignivo_page_header.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/brand_tokens.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key, this.api});
  final FireguardApiService? api;

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  late final _api = widget.api ?? FireguardApiService.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _contacts = [];
  String? _errorMessage;

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_api.lastError ?? 'Thao tác không thành công.')),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await _api.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh bạ từ FireGuard: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleContact(Map<String, dynamic> contact) async {
    final id = contact['id'] as int;
    final currentEnabled =
        contact['enabled'] == true || contact['enabled'] == 1;
    final ok = await _api.updateContact(id, {'enabled': !currentEnabled});
    if (ok) {
      _fetchContacts();
    } else {
      _showError();
    }
  }

  Future<void> _deleteContact(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: const Text(
          'Bạn có chắc muốn xoá liên hệ khẩn cấp này khỏi danh sách gọi Stringee?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? BrandTokens.darkCriticalFg
                  : BrandTokens.criticalFg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await _api.deleteContact(id);
      if (ok) {
        _fetchContacts();
      } else {
        _showError();
      }
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    String kind = 'family';
    int priority = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text(
            'Thêm liên hệ khẩn cấp',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên người nhận (ví dụ: Mẹ, Bảo vệ)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại (0912345678)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quan hệ (bố, mẹ, bảo vệ toà nhà...)',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhóm người nhận',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'family',
                      child: Text(
                        'Người thân (family)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'fire_dept',
                      child: Text(
                        'PCCC / Bảo vệ toà nhà (fire_dept)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => setDlgState(() => kind = v ?? 'family'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: priority,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Thứ tự ưu tiên gọi',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        'Ưu tiên 1 (Gọi trước)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(
                        'Ưu tiên 2',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(
                        'Ưu tiên 3',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => setDlgState(() => priority = v ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                final res = await _api.createContact(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  relation: relationCtrl.text.trim(),
                  kind: kind,
                  priority: priority,
                );
                if (res != null) {
                  _fetchContacts();
                } else {
                  _showError();
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: ignivoDetailAppBar(
        context,
        title: 'Danh bạ khẩn cấp (Stringee)',
        subtitle: 'Danh bạ nhận cuộc gọi cảnh báo',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchContacts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: isDark ? BrandTokens.darkOnPrimary : Colors.white,
        onPressed: _api.canConfigure ? _showAddDialog : null,
        icon: const Icon(Icons.add),
        label: const Text(
          'Thêm liên hệ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: isDark
                          ? BrandTokens.darkCriticalFg
                          : BrandTokens.criticalFg,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? BrandTokens.darkTextSecondary
                            : BrandTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchContacts,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contacts_outlined,
                    size: 54,
                    color: isDark
                        ? BrandTokens.darkTextTertiary
                        : BrandTokens.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có số điện thoại khẩn cấp nào.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? BrandTokens.darkTextSecondary
                          : BrandTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bấm nút bên dưới để thêm người thân hoặc số cứu hoả.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? BrandTokens.darkTextTertiary
                          : BrandTokens.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _contacts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = _contacts[index];
                final id = c['id'] as int;
                final name = c['name']?.toString() ?? '';
                final phone = c['phone']?.toString() ?? '';
                final kind = c['kind']?.toString() ?? 'family';
                final isEnabled = c['enabled'] == true || c['enabled'] == 1;
                final isFamily = kind == 'family';
                final badgeBg = isFamily
                    ? (isDark
                          ? BrandTokens.darkBrandTint
                          : BrandTokens.brandTint)
                    : (isDark
                          ? BrandTokens.darkCriticalBg
                          : BrandTokens.criticalBg);
                final badgeFg = isFamily
                    ? (isDark
                          ? BrandTokens.darkPrimary
                          : BrandTokens.brandPrimary)
                    : (isDark
                          ? BrandTokens.darkCriticalFg
                          : BrandTokens.criticalFg);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                    border: Border.all(
                      color: isDark
                          ? BrandTokens.darkBorder
                          : BrandTokens.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: badgeBg,
                        child: Icon(
                          isFamily
                              ? Icons.family_restroom_rounded
                              : Icons.local_fire_department_rounded,
                          color: badgeFg,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isFamily ? 'Người thân' : 'PCCC/Bảo vệ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: badgeFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$phone ${c['relation'] != null && c['relation'].toString().isNotEmpty ? "• ${c['relation']}" : ""}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? BrandTokens.darkTextSecondary
                                    : BrandTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEnabled,
                        activeThumbColor: isDark
                            ? BrandTokens.darkPrimary
                            : BrandTokens.brandPrimary,
                        onChanged: _api.canConfigure
                            ? (_) => _toggleContact(c)
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: isDark
                              ? BrandTokens.darkTextTertiary
                              : BrandTokens.textTertiary,
                          size: 20,
                        ),
                        onPressed: _api.canConfigure
                            ? () => _deleteContact(id)
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
