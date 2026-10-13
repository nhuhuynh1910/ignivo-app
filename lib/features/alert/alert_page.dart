import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert_model.dart';
import '../../models/system_model.dart';
import '../../widgets/alert_card.dart';
import 'alert_detail_page.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({
    super.key,
  });

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  final AuthService _authService = AuthService();

  final FirestoreService _firestoreService =
  FirestoreService();

  String? _selectedSystemId;

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Cảnh báo',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchUserSystems(
          uid,
        ),
        builder: (
            context,
            systemSnapshot,
            ) {
          if (systemSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (systemSnapshot.hasError) {
            return const Center(
              child: Text(
                'Không thể tải hệ thống.',
              ),
            );
          }

          final systems =
              systemSnapshot.data?.docs
                  .map(
                IgnivoSystem.fromFirestore,
              )
                  .toList() ??
                  [];

          if (systems.isEmpty) {
            return const _NoSystemState();
          }

          final selectedIndex =
          systems.indexWhere(
                (system) =>
            system.id == _selectedSystemId,
          );

          final selectedSystem =
          selectedIndex >= 0
              ? systems[selectedIndex]
              : systems.first;

          return Column(
            children: [
              // ============================================================
              // SYSTEM FILTER
              // ============================================================

              _SystemFilter(
                systems: systems,
                selectedSystemId:
                selectedSystem.id,
                onSelected: (
                    systemId,
                    ) {
                  setState(() {
                    _selectedSystemId =
                        systemId;
                  });
                },
              ),

              // ============================================================
              // ALERT LIST
              // ============================================================

              Expanded(
                child: _AlertList(
                  systemId:
                  selectedSystem.id,
                  firestoreService:
                  _firestoreService,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// SYSTEM FILTER
// ============================================================================

class _SystemFilter extends StatelessWidget {
  const _SystemFilter({
    required this.systems,
    required this.selectedSystemId,
    required this.onSelected,
  });

  final List<IgnivoSystem> systems;
  final String selectedSystemId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        14,
      ),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection:
          Axis.horizontal,
          itemCount: systems.length,
          separatorBuilder: (_, index) => const SizedBox(width: 8),
          itemBuilder: (
              context,
              index,
              ) {
            final system =
            systems[index];

            final selected =
                system.id ==
                    selectedSystemId;

            return InkWell(
              onTap: () {
                onSelected(
                  system.id,
                );
              },
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                alignment:
                Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.backgroundSoft,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors
                        .backgroundBlueSoft,
                  ),
                ),
                child: Text(
                  system.name,
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors
                        .textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ALERT LIST
// ============================================================================

class _AlertList extends StatelessWidget {
  const _AlertList({
    required this.systemId,
    required this.firestoreService,
  });

  final String systemId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream:
      firestoreService.watchAlerts(
        systemId,
      ),
      builder: (
          context,
          snapshot,
          ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Không thể tải cảnh báo.',
            ),
          );
        }

        final alerts =
            snapshot.data?.docs
                .map(
                  (
                  document,
                  ) =>
                  AlertModel.fromFirestore(
                    document,
                    systemId:
                    systemId,
                  ),
            )
                .toList() ??
                [];

        if (alerts.isEmpty) {
          return const _EmptyAlerts();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(
            16,
          ),
          itemCount: alerts.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (
              context,
              index,
              ) {
            final alert =
            alerts[index];

            return AlertCard(
              alert: alert,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AlertDetailPage(
                          alert: alert,
                        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// EMPTY ALERT
// ============================================================================

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 54,
              color:
              AppColors.textTertiary,
            ),

            SizedBox(
              height: 14,
            ),

            Text(
              'Không có cảnh báo',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
                color:
                AppColors.textPrimary,
              ),
            ),

            SizedBox(
              height: 7,
            ),

            Text(
              'Hệ thống hiện không có cảnh báo.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NO SYSTEM
// ============================================================================

class _NoSystemState extends StatelessWidget {
  const _NoSystemState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.home_outlined,
              size: 54,
              color:
              AppColors.textTertiary,
            ),

            SizedBox(
              height: 14,
            ),

            Text(
              'Chưa có hệ thống IGNIVO',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
                color:
                AppColors.textPrimary,
              ),
            ),

            SizedBox(
              height: 7,
            ),

            Text(
              'Hãy thêm hệ thống để theo dõi cảnh báo.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}