import 'package:flutter/material.dart';
import '../../core/services/fireguard_api_service.dart';
import '../../core/theme/app_theme.dart';

class EmergencyLocationPage extends StatefulWidget {
  const EmergencyLocationPage({super.key, this.api});
  final FireguardApiService? api;

  @override
  State<EmergencyLocationPage> createState() => _EmergencyLocationPageState();
}

class _EmergencyLocationPageState extends State<EmergencyLocationPage> {
  late final _api = widget.api ?? FireguardApiService.instance;

  final _addressCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;
  double? _latitude, _longitude;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    _roomCtrl.dispose();
    _landmarkCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() => _loading = true);
    final data = await _api.getLocationSettings();
    if (!mounted) return;
    if (data != null) {
      _loaded = true;
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
      _addressCtrl.text = data['address']?.toString() ?? '';
      _buildingCtrl.text = data['building']?.toString() ?? '';
      _floorCtrl.text = data['floor']?.toString() ?? '';
      _roomCtrl.text = data['room']?.toString() ?? '';
      _landmarkCtrl.text = data['landmark']?.toString() ?? '';
      _notesCtrl.text = data['notes']?.toString() ?? '';
    }
    setState(() {
      _loading = false;
      _error = data == null ? _api.lastError : null;
    });
  }

  Future<void> _saveLocation() async {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập địa chỉ đầy đủ để đọc qua điện thoại!'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await _api.updateLocationSettings(
      address: _addressCtrl.text.trim(),
      building: _buildingCtrl.text.trim(),
      floor: _floorCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật vị trí & địa chỉ khẩn cấp thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _api.lastError ?? 'Không thể lưu cấu hình vị trí lên FireGuard.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Vị trí & Địa chỉ khẩn cấp',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!),
                // HƯỚNG DẪN
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Địa chỉ này sẽ được giọng đọc AI của FireGuard đọc trực tiếp qua điện thoại cho người thân và lực lượng cứu hộ khi xảy ra hỏa hoạn.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.backgroundBlueSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ đầy đủ (*)',
                          hintText:
                              'Ví dụ: 123 Nguyễn Trãi, Thanh Xuân, Hà Nội',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _buildingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Toà nhà / Khu',
                          hintText: 'Ví dụ: Chung cư ABC, toà B',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _floorCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tầng',
                                hintText: 'Ví dụ: 2',
                                prefixIcon: Icon(Icons.stairs_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _roomCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phòng / Khu vực',
                                hintText: 'Ví dụ: Bếp',
                                prefixIcon: Icon(
                                  Icons.room_preferences_rounded,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _landmarkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Điểm mốc nhận diện',
                          hintText: 'Ví dụ: đối diện chợ Thượng Đình',
                          prefixIcon: Icon(Icons.flag_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú cho cứu hộ',
                          hintText: 'Ví dụ: Cổng phụ phía sau, mã cổng 1234',
                          prefixIcon: Icon(Icons.note_alt_rounded),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: _saving || !_loaded || !_api.canConfigure
                              ? null
                              : _saveLocation,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _saving ? 'Đang lưu...' : 'Lưu địa chỉ khẩn cấp',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
