import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/edge_pairing_service.dart';
import '../../core/theme/app_theme.dart';

class PairEdgeBoxPage extends StatefulWidget {
  const PairEdgeBoxPage({super.key});

  @override
  State<PairEdgeBoxPage> createState() => _PairEdgeBoxPageState();
}

class _PairEdgeBoxPageState extends State<PairEdgeBoxPage> {
  final _formKey = GlobalKey<FormState>();
  final _edgeCodeController = TextEditingController();

  final AuthService _authService = AuthService();
  final EdgePairingService _pairingService = EdgePairingService();

  bool _loading = false;

  @override
  void dispose() {
    _edgeCodeController.dispose();
    super.dispose();
  }

  Future<void> _pairEdgeBox() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _authService.currentUserId;
    if (uid == null) return;

    final code = _edgeCodeController.text.trim().toUpperCase();

    setState(() {
      _loading = true;
    });

    try {
      await _pairingService.claimEdgeBox(
        ownerId: uid,
        edgeCode: code,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kết nối Edge Box thành công! IP Camera đang tự động đồng bộ.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể liên kết Edge Box. Vui lòng kiểm tra lại mã.'),
          backgroundColor: AppColors.danger,
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
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Kết nối IGNIVO Edge Box',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                Center(
                  child: Image.asset(
                    'assets/images/ignivo_logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'KẾT NỐI THIẾT BỊ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Nhập mã Edge Box in trên thiết bị Raspberry Pi 5 để bắt đầu giám sát.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _edgeCodeController,
                  autocorrect: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: AppColors.primary,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _pairEdgeBox(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập mã Edge Box';
                    }
                    if (value.trim().length < 4) {
                      return 'Mã Edge Box không hợp lệ';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Mã IGNIVO Edge Box',
                    hintText: 'IGV-XXXX-XXXX',
                    prefixIcon: Icon(Icons.memory_rounded),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Mã được in trên nhãn dán phía sau thiết bị IGNIVO Edge Box.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 36),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _pairEdgeBox,
                    child: _loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'KẾT NỐI EDGE BOX',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
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
