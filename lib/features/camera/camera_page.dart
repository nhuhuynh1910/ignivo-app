import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/camera_model.dart';
import '../../models/system_model.dart';
import '../../widgets/camera_card.dart';
import 'camera_detail_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String? _selectedSystemId;
  String _filter = 'ALL'; // ALL, ONLINE, OFFLINE

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Camera IP',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchUserSystems(uid),
        builder: (context, systemSnapshot) {
          if (systemSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final systems = systemSnapshot.data?.docs
              .map(IgnivoSystem.fromFirestore)
              .toList() ??
              [];

          if (systems.isEmpty) {
            return const Center(child: Text('Bạn chưa kết nối IGNIVO Edge Box.'));
          }

          final selectedSystem = systems.firstWhere(
                (sys) => sys.id == _selectedSystemId,
            orElse: () => systems.first,
          );

          return Column(
            children: [
              // System filter chip row
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: systems.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final sys = systems[index];
                      final selected = sys.id == selectedSystem.id;

                      return ChoiceChip(
                        label: Text(sys.name),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _selectedSystemId = sys.id),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.backgroundSoft,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Status Filter Tabs [ Tất cả ] [ Online ] [ Offline ]
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tất cả',
                      selected: _filter == 'ALL',
                      onTap: () => setState(() => _filter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Online',
                      selected: _filter == 'ONLINE',
                      onTap: () => setState(() => _filter = 'ONLINE'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Offline',
                      selected: _filter == 'OFFLINE',
                      onTap: () => setState(() => _filter = 'OFFLINE'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.watchCameras(selectedSystem.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var cameras = snapshot.data?.docs
                        .map((doc) => CameraModel.fromFirestore(doc, systemId: selectedSystem.id))
                        .toList() ??
                        [];

                    if (_filter == 'ONLINE') {
                      cameras = cameras.where((c) => c.online).toList();
                    } else if (_filter == 'OFFLINE') {
                      cameras = cameras.where((c) => !c.online).toList();
                    }

                    if (cameras.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không có camera nào.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cameras.length,
                      itemBuilder: (context, index) {
                        final camera = cameras[index];
                        return CameraCard(
                          camera: camera,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CameraDetailPage(camera: camera),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.deepBlue : AppColors.backgroundBlueSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
