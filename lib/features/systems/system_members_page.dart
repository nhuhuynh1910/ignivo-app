import 'package:flutter/material.dart';
import '../../core/models/system_record.dart';
import '../../core/services/cloud_sharing_service.dart';
import '../../core/theme/brand_tokens.dart';

class SystemMembersPage extends StatefulWidget {
  const SystemMembersPage({
    super.key,
    required this.system,
    this.sharingService,
  });

  final SystemRecord system;
  final CloudSharingService? sharingService;

  @override
  State<SystemMembersPage> createState() => _SystemMembersPageState();
}

class _SystemMembersPageState extends State<SystemMembersPage> {
  late final CloudSharingService _sharingService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sharingService = widget.sharingService ?? CloudSharingService();
  }

  Color _getRoleColor(String role, bool isDark) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return BrandTokens.brandPrimary;
      case 'ADMIN':
        return Colors.indigo;
      case 'OPERATOR':
        return isDark ? BrandTokens.stitchDarkOnlineFg : BrandTokens.stitchOnlineFg;
      case 'VIEWER':
      default:
        return isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Chủ sở hữu';
      case 'ADMIN':
        return 'Quản trị viên';
      case 'OPERATOR':
        return 'Vận hành';
      case 'VIEWER':
      default:
        return 'Chỉ xem';
    }
  }

  Future<void> _openInviteDialog() async {
    final emailController = TextEditingController();
    String selectedRole = 'OPERATOR';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: BrandTokens.brandPrimary),
                SizedBox(width: 8),
                Text('Mời thành viên mới'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập email của người bạn muốn cấp quyền truy cập hệ thống "${widget.system.systemName}":',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email thành viên',
                      hintText: 'vidu@gmail.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Phân quyền (RBAC):',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('Quản trị viên (Admin) - Toàn quyền cấu hình'),
                      ),
                      DropdownMenuItem(
                        value: 'OPERATOR',
                        child: Text('Vận hành (Operator) - Xử lý sự cố, xem camera'),
                      ),
                      DropdownMenuItem(
                        value: 'VIEWER',
                        child: Text('Chỉ xem (Viewer) - Chỉ theo dõi, không xử lý sự cố'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  if (emailController.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Gửi lời mời'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      final email = emailController.text.trim();
      setState(() => _isLoading = true);
      try {
        await _sharingService.createInvitation(
          systemId: widget.system.systemId,
          inviteeEmail: email,
          role: selectedRole,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gửi lời mời tới $email thành công!'),
              backgroundColor: BrandTokens.stitchSafe,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi gửi lời mời: $e'),
              backgroundColor: BrandTokens.stitchCriticalFg,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmRevokeMember(Map<String, dynamic> member) async {
    final uid = member['uid']?.toString() ?? '';
    final email = member['email']?.toString() ?? uid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền truy cập?'),
        content: Text(
          'Bạn có chắc chắn muốn thu hồi quyền của thành viên "$email"? Người này sẽ mất quyền xem và vận hành hệ thống ngay lập tức.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrandTokens.stitchCriticalFg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _sharingService.revokeMembership(
          systemId: widget.system.systemId,
          targetUid: uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thu hồi quyền của $email'),
              backgroundColor: BrandTokens.stitchSafe,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi thu hồi quyền: $e'),
              backgroundColor: BrandTokens.stitchCriticalFg,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quản lý thành viên & Chia sẻ'),
            Text(
              widget.system.systemName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Mời thành viên',
            onPressed: _openInviteDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BrandTokens.brandPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                      border: Border.all(
                        color: BrandTokens.brandPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded, color: BrandTokens.brandPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Phân quyền dựa trên vai trò (RBAC): Chỉ OWNER và ADMIN được quản lý thành viên. VIEWER chỉ có thể xem camera và thông báo sự cố.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Thành viên hiện tại
                  Text(
                    'Thành viên hiện tại',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _sharingService.watchMembers(widget.system.systemId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final members = snapshot.data ?? [];
                      if (members.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Chưa có thành viên nào được thêm.',
                                style: TextStyle(
                                  color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {

                          final member = members[index];
                          final role = member['role']?.toString() ?? 'VIEWER';
                          final status = member['status']?.toString() ?? 'active';
                          final isRevoked = status == 'revoked';
                          final email = member['email']?.toString() ?? member['uid']?.toString() ?? '';
                          final isOwner = role == 'OWNER';

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                              side: BorderSide(
                                color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(role, isDark).withValues(alpha: 0.15),
                                child: Text(
                                  email.isNotEmpty ? email[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getRoleColor(role, isDark),
                                  ),
                                ),
                              ),
                              title: Text(
                                email,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: isRevoked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(role, isDark).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getRoleLabel(role),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getRoleColor(role, isDark),
                                      ),
                                    ),
                                  ),
                                  if (isRevoked) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: BrandTokens.stitchCriticalBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Đã thu hồi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: BrandTokens.stitchCriticalFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: !isOwner && !isRevoked
                                  ? IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      tooltip: 'Thu hồi quyền',
                                      onPressed: () => _confirmRevokeMember(member),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Section 2: Lời mời đã gửi đang chờ chấp nhận
                  Text(
                    'Lời mời đang chờ phản hồi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _sharingService.watchSystemInvitations(widget.system.systemId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final invitations = snapshot.data
                              ?.where((inv) => inv['status'] == 'pending')
                              .toList() ??
                          [];

                      if (invitations.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Không có lời mời nào đang chờ.',
                                style: TextStyle(
                                  color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: invitations.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),

                        itemBuilder: (context, index) {
                          final inv = invitations[index];
                          final email = inv['inviteeEmail']?.toString() ?? '';
                          final role = inv['role']?.toString() ?? 'VIEWER';

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.mail_outline_rounded, color: Colors.orange),
                              title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Vai trò mời: ${_getRoleLabel(role)} • Đang chờ người dùng đồng ý',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
