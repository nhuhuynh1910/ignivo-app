import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/realtime_database_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/camera_model.dart';
import '../../models/edge_live_status_model.dart';
import '../../models/system_model.dart';
import '../../widgets/camera_card.dart';
import '../camera/camera_detail_page.dart';
import '../settings/personal_info_page.dart';
import '../system/pair_edge_box_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final RealtimeDatabaseService _rtdbService = RealtimeDatabaseService();

  String? _selectedSystemId;

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
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/ignivo_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'IGNIVO',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.deepBlue,
                letterSpacing: -1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kết nối Edge Box mới',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PairEdgeBoxPage()),
              );
            },
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
          ),
          const SizedBox(width: 2),
          _ProfileAvatar(uid: uid, firestoreService: _firestoreService),
          const SizedBox(width: 14),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchUserSystems(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _ErrorState();
          }

          final documents = snapshot.data?.docs ?? [];
          final systems = documents.map(IgnivoSystem.fromFirestore).toList();

          if (systems.isEmpty) {
            return _EmptySystemState(
              onAddSystem: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PairEdgeBoxPage()),
                );
              },
            );
          }

          IgnivoSystem selectedSystem = systems.first;
          if (_selectedSystemId != null) {
            for (final system in systems) {
              if (system.id == _selectedSystemId) {
                selectedSystem = system;
                break;
              }
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                child: _SystemSelector(
                  systems: systems,
                  selectedSystemId: selectedSystem.id,
                  onSelected: (id) {
                    setState(() {
                      _selectedSystemId = id;
                    });
                  },
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Tổng quan Edge Box',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Trạng thái Raspberry Pi 5 và AI Hailo-8L.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Stream Edge Status from Realtime Database
                      StreamBuilder<EdgeLiveStatus>(
                        stream: _rtdbService.watchEdgeStatus(selectedSystem.id),
                        builder: (context, edgeSnapshot) {
                          final edgeStatus = edgeSnapshot.data ?? const EdgeLiveStatus();

                          return _SystemSummaryCard(
                            system: selectedSystem,
                            edgeStatus: edgeStatus,
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Danh sách Camera',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _CamerasSection(
                        systemId: selectedSystem.id,
                        firestoreService: _firestoreService,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.uid, required this.firestoreService});

  final String uid;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestoreService.watchUserProfile(uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name']?.toString().trim() ?? '';
        final photoUrl = data?['photoUrl']?.toString().trim() ?? '';
        final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PersonalInfoPage()),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.backgroundBlueSoft,
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SystemSelector extends StatelessWidget {
  const _SystemSelector({
    required this.systems,
    required this.selectedSystemId,
    required this.onSelected,
  });

  final List<IgnivoSystem> systems;
  final String selectedSystemId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: systems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final system = systems[index];
          final selected = system.id == selectedSystemId;

          return ChoiceChip(
            label: Text(system.name),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(system.id),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.backgroundSoft,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.backgroundBlueSoft,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          );
        },
      ),
    );
  }
}

class _SystemSummaryCard extends StatelessWidget {
  const _SystemSummaryCard({
    required this.system,
    required this.edgeStatus,
  });

  final IgnivoSystem system;
  final EdgeLiveStatus edgeStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0080F0),
            Color(0xFF0030B0),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.memory_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mã Edge: ${system.edgeCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  edgeStatus.safetyStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _StatusItem(
                label: 'Edge Box',
                value: edgeStatus.online ? 'Online' : 'Offline',
                active: edgeStatus.online,
              ),
              _StatusItem(
                label: 'AI Hailo-8L',
                value: edgeStatus.aiOnline ? 'Active' : 'Offline',
                active: edgeStatus.aiOnline,
              ),
              _StatusItem(
                label: 'Internet',
                value: edgeStatus.internetAvailable ? 'Connected' : 'Offline',
                active: edgeStatus.internetAvailable,
              ),
              _StatusItem(
                label: 'Camera',
                value: '${system.cameraCount}',
                active: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _CamerasSection extends StatelessWidget {
  const _CamerasSection({
    required this.systemId,
    required this.firestoreService,
  });

  final String systemId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestoreService.watchCameras(systemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final cameras = snapshot.data?.docs
            .map((doc) => CameraModel.fromFirestore(doc, systemId: systemId))
            .toList() ??
            [];

        if (cameras.isEmpty) {
          return const _EmptyCamerasState();
        }

        return Column(
          children: cameras
              .map((camera) => CameraCard(
            camera: camera,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CameraDetailPage(camera: camera),
                ),
              );
            },
          ))
              .toList(),
        );
      },
    );
  }
}

class _EmptySystemState extends StatelessWidget {
  const _EmptySystemState({required this.onAddSystem});

  final VoidCallback onAddSystem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ignivo_logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có IGNIVO Edge Box',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập mã Edge Box (Raspberry Pi 5) để bắt đầu sử dụng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onAddSystem,
                icon: const Icon(Icons.memory_rounded),
                label: const Text('KẾT NỐI EDGE BOX'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCamerasState extends StatelessWidget {
  const _EmptyCamerasState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.videocam_outlined, size: 42, color: AppColors.textTertiary),
          SizedBox(height: 10),
          Text(
            'Chưa có Camera',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Raspberry Pi 5 sẽ tự động phát hiện IP Camera trong mạng nội bộ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Không thể tải dữ liệu hệ thống.'));
  }
}
