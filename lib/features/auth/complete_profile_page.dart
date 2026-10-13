import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({
    super.key,
    required this.user,
  });

  final User user;

  @override
  State<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState
    extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final FirestoreService _firestoreService =
  FirestoreService();

  late final TextEditingController _nameController;
  final TextEditingController _phoneController =
  TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }

    if (value.trim().length < 2) {
      return 'Tên không hợp lệ';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }

    final normalized =
    phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (!RegExp(r'^\+?[0-9]{9,15}$')
        .hasMatch(normalized)) {
      return 'Số điện thoại không hợp lệ';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _firestoreService.completeUserProfile(
        user: widget.user,
        name: _nameController.text,
        phone: _phoneController.text,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể lưu thông tin. Vui lòng thử lại.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hoàn tất hồ sơ'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundBlueSoft,
                    borderRadius:
                    BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Hoàn tất thông tin tài khoản',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'IGNIVO yêu cầu số điện thoại để hoàn tất tài khoản.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon:
                    Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  initialValue: widget.user.email ?? '',
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                    Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: _validatePhone,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    hintText: 'Ví dụ: 0901234567',
                    prefixIcon:
                    Icon(Icons.phone_outlined),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Hoàn tất',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}