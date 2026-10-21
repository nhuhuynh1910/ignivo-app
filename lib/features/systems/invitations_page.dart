import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/cloud_sharing_service.dart';
import '../../core/services/system_session_manager.dart';
import '../../core/theme/brand_tokens.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({
    super.key,
    required this.sessionManager,
    this.sharingService,
    this.userEmail,
  });

  final SystemSessionManager sessionManager;
  final CloudSharingService? sharingService;
  final String? userEmail;

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  late final CloudSharingService _sharingService;
  late final String _email;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sharingService = widget.sharingService ?? CloudSharingService();
    _email = widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';
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

  Future<void> _acceptInvitation(Map<String, dynamic> inv) async {
    final invitationId = inv['invitationId']?.toString() ?? '';
    final systemName = inv['systemName']?.toString() ?? 'Hệ thống Ignivo';

    setState(() => _isLoading = true);
    try {
      await _sharingService.acceptInvitation(invitationId);
      // Nạp lại danh mục hệ thống
      await widget.sessionManager.initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tham gia hệ thống "$systemName" thành công!'),
            backgroundColor: BrandTokens.stitchSafe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chấp nhận lời mời: $e'),
            backgroundColor: BrandTokens.stitchCriticalFg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lời mời tham gia hệ thống'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _email.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Tài khoản hiện tại chưa có thông tin email để nhận lời mời.',
                      style: TextStyle(
                        color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sharingService.watchPendingInvitations(_email),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final invitations = snapshot.data ?? [];
                    if (invitations.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: BrandTokens.brandPrimary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 64,
                                  color: BrandTokens.brandPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Không có lời mời nào',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Khi chủ sở hữu hệ thống Edge Box khác chia sẻ quyền quản trị hoặc theo dõi tới email $_email, lời mời sẽ xuất hiện tại đây.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: invitations.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),

                      itemBuilder: (context, index) {
                        final inv = invitations[index];
                        final systemName = inv['systemName']?.toString() ?? 'Hệ thống Ignivo';
                        final role = inv['role']?.toString() ?? 'VIEWER';

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                            side: BorderSide(
                              color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: BrandTokens.brandPrimary,
                                      child: Icon(Icons.hub_outlined, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            systemName,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Vai trò được cấp: ${_getRoleLabel(role)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? BrandTokens.darkTextSecondary : BrandTokens.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => _acceptInvitation(inv),
                                      icon: const Icon(Icons.check_rounded, size: 18),
                                      label: const Text('Chấp nhận lời mời'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: BrandTokens.stitchSafe,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
