import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_tokens.dart';
import '../../widgets/ignivo_avatar.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _photoUrlController;

  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _photoUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _populateForm(Map<String, dynamic> data) {
    if (_isInitialized) return;

    final String name = (data['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? '').toString().trim();
    final String phone = (data['phone'] ?? '').toString().trim();

    String photo = '';
    final keys = ['photoUrl', 'photoURL', 'avatar_url', 'avatar', 'photo'];
    for (final k in keys) {
      if (data[k] != null && data[k].toString().trim().isNotEmpty) {
        photo = data[k].toString().trim();
        break;
      }
    }
    if (photo.isEmpty) {
      photo = FirebaseAuth.instance.currentUser?.photoURL ?? '';
    }

    _nameController.text = name;
    _phoneController.text = phone;
    _photoUrlController.text = photo;
    _isInitialized = true;
  }

  Future<void> _saveProfile(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final photoUrl = _photoUrlController.text.trim();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phone': phone,
        'photoUrl': photoUrl,
        'photoURL': photoUrl, // Synchronize both keys for compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update Firebase Auth user profile if available
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          if (name.isNotEmpty) await currentUser.updateDisplayName(name);
          if (photoUrl.isNotEmpty) await currentUser.updatePhotoURL(photoUrl);
        }
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.success,
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Đã cập nhật hồ sơ cá nhân thành công!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật hồ sơ: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAvatarEditDialog(String currentUrl) {
    final tempController = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Đổi ảnh đại diện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập liên kết (URL) ảnh đại diện của bạn (ví dụ từ Google, Imgur hoặc GitHub):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tempController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/avatar.jpg',
                labelText: 'URL Ảnh đại diện',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() {
                _photoUrlController.text = tempController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy tài khoản.')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? BrandTokens.darkBackground : BrandTokens.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchUserProfile(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? {};
          _populateForm(data);

          final email = data['email']?.toString().trim() ??
              _authService.currentUserEmail ??
              '';
          final authProvider = data['authProvider']?.toString().trim() ?? 'google';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    // ===============================================
                    // PROFILE HEADER WITH AVATAR
                    // ===============================================
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: BrandTokens.primaryGradient,
                        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: BrandTokens.brandNavy.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          IgnivoUserAvatar(
                            name: _nameController.text,
                            photoUrl: _photoUrlController.text,
                            data: data,
                            radius: 46,
                            showBorder: true,
                            showEditIcon: true,
                            onTap: () => _showAvatarEditDialog(_photoUrlController.text),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text
                                : 'Người dùng IGNIVO',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            email.isNotEmpty ? email : 'Chưa có email',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===============================================
                    // FORM INPUTS CARD
                    // ===============================================
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? BrandTokens.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                        border: Border.all(
                          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                        ),
                        boxShadow: BrandTokens.softShadow(isDark: isDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHỈNH SỬA THÔNG TIN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? BrandTokens.darkTextSecondary
                                  : BrandTokens.brandNavy,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                          ),

                          const SizedBox(height: 16),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại liên hệ',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Avatar URL input
                          TextFormField(
                            controller: _photoUrlController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Liên kết ảnh đại diện (URL)',
                              prefixIcon: const Icon(Icons.link_rounded),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                tooltip: 'Xem trước / Thay đổi',
                                onPressed: () => _showAvatarEditDialog(_photoUrlController.text),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Email Readonly
                          TextFormField(
                            initialValue: email,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Email tài khoản (Readonly)',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Provider Readonly
                          TextFormField(
                            initialValue: _providerLabel(authProvider),
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Phương thức đăng nhập',
                              prefixIcon: Icon(Icons.login_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===============================================
                    // SAVE BUTTON
                    // ===============================================
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _isSaving ? null : () => _saveProfile(uid),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Đang lưu...' : 'LƯU THAY ĐỔI HỒ SƠ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BrandTokens.darkSurfaceVariant.withValues(alpha: 0.5)
                            : BrandTokens.brandTint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Thông tin này được dùng để hiển thị trên hệ thống quản trị IGNIVO Edge Box và đồng bộ cho dịch vụ gọi điện khẩn cấp.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: isDark
                                    ? BrandTokens.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'Tài khoản Google';
      case 'password':
        return 'Email và Mật khẩu';
      default:
        return provider.isEmpty ? 'Chưa xác định' : provider;
    }
  }
}
