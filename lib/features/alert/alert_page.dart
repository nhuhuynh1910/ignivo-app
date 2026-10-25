import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_tokens.dart';
import '../../models/alert_model.dart';
import '../../models/system_model.dart';
import '../../widgets/alert_card.dart';
import 'alert_detail_page.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String? _selectedSystemId;
  String _severityFilter = 'ALL'; // ALL, CRITICAL, WARNING, NORMAL, UNACKNOWLEDGED

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? BrandTokens.darkBackground : BrandTokens.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'Cảnh báo & Sự cố',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchUserSystems(uid),
        builder: (context, systemSnapshot) {
          if (systemSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (systemSnapshot.hasError) {
            return const Center(child: Text('Không thể tải danh sách hệ thống.'));
          }

          final systems = systemSnapshot.data?.docs
                  .map(IgnivoSystem.fromFirestore)
                  .toList() ??
              [];

          if (systems.isEmpty) {
            return const _NoSystemState();
          }

          final selectedSystem = systems.firstWhere(
            (sys) => sys.id == _selectedSystemId,
            orElse: () => systems.first,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System selector bar matching Home Page format
              Container(
                width: double.infinity,
                color: isDark ? BrandTokens.darkSurface : Colors.white,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                child: _SystemSelector(
                  systems: systems,
                  selectedSystemId: selectedSystem.id,
                  onSelected: (id) => setState(() => _selectedSystemId = id),
                ),
              ),

              // Scrollable content body matching Home Page layout
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.watchAlerts(selectedSystem.id),
                  builder: (context, alertSnapshot) {
                    final rawAlerts = alertSnapshot.data?.docs
                            .map((doc) => AlertModel.fromFirestore(doc, systemId: selectedSystem.id))
                            .toList() ??
                        [];

                    // Calculate Summary Stats
                    final totalCount = rawAlerts.length;
                    final criticalCount = rawAlerts
                        .where((a) => a.severity.toUpperCase() == 'CRITICAL')
                        .length;
                    final warningCount = rawAlerts
                        .where((a) =>
                            a.severity.toUpperCase() == 'ALERT' ||
                            a.severity.toUpperCase() == 'SUSPICIOUS')
                        .length;
                    final unackCount = rawAlerts.where((a) => !a.acknowledged).length;

                    // Filter alerts based on active filter chip
                    var filteredAlerts = rawAlerts;
                    if (_severityFilter == 'CRITICAL') {
                      filteredAlerts = rawAlerts
                          .where((a) => a.severity.toUpperCase() == 'CRITICAL')
                          .toList();
                    } else if (_severityFilter == 'WARNING') {
                      filteredAlerts = rawAlerts
                          .where((a) =>
                              a.severity.toUpperCase() == 'ALERT' ||
                              a.severity.toUpperCase() == 'SUSPICIOUS')
                          .toList();
                    } else if (_severityFilter == 'NORMAL') {
                      filteredAlerts = rawAlerts
                          .where((a) => a.severity.toUpperCase() == 'NORMAL')
                          .toList();
                    } else if (_severityFilter == 'UNACKNOWLEDGED') {
                      filteredAlerts = rawAlerts.where((a) => !a.acknowledged).toList();
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Overview title matching Home Page format
                              Text(
                                'Tổng quan Cảnh báo',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? BrandTokens.darkTextPrimary
                                      : BrandTokens.brandNavy,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Theo dõi các thông báo nhận diện cháy, khói và sự cố từ Edge Box.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? BrandTokens.darkTextTertiary
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // System Alert Summary Banner (Home Page format)
                              _AlertSummaryCard(
                                system: selectedSystem,
                                totalAlerts: totalCount,
                                criticalAlerts: criticalCount,
                                warningAlerts: warningCount,
                                unackAlerts: unackCount,
                              ),

                              const SizedBox(height: 24),

                              // Filter Pills
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _FilterPill(
                                      label: 'Tất cả ($totalCount)',
                                      selected: _severityFilter == 'ALL',
                                      onTap: () => setState(() => _severityFilter = 'ALL'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterPill(
                                      label: 'Chưa xử lý ($unackCount)',
                                      selected: _severityFilter == 'UNACKNOWLEDGED',
                                      color: BrandTokens.criticalFg,
                                      onTap: () => setState(() => _severityFilter = 'UNACKNOWLEDGED'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterPill(
                                      label: 'Nguy hiểm ($criticalCount)',
                                      selected: _severityFilter == 'CRITICAL',
                                      color: BrandTokens.criticalFg,
                                      onTap: () => setState(() => _severityFilter = 'CRITICAL'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterPill(
                                      label: 'Cảnh báo ($warningCount)',
                                      selected: _severityFilter == 'WARNING',
                                      color: BrandTokens.mediumFg,
                                      onTap: () => setState(() => _severityFilter = 'WARNING'),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Danh sách Cảnh báo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? BrandTokens.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (alertSnapshot.connectionState == ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (filteredAlerts.isEmpty)
                                const _EmptyAlerts()
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredAlerts.length,
                                  itemBuilder: (context, index) {
                                    final alert = filteredAlerts[index];
                                    return AlertCard(
                                      alert: alert,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => AlertDetailPage(alert: alert),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
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

class _AlertSummaryCard extends StatelessWidget {
  const _AlertSummaryCard({
    required this.system,
    required this.totalAlerts,
    required this.criticalAlerts,
    required this.warningAlerts,
    required this.unackAlerts,
  });

  final IgnivoSystem system;
  final int totalAlerts;
  final int criticalAlerts;
  final int warningAlerts;
  final int unackAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: BrandTokens.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandTokens.brandNavy.withValues(alpha: 0.3),
            blurRadius: 18,
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
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 26,
                ),
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
                      'Edge Code: ${system.edgeCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: unackAlerts > 0
                      ? BrandTokens.criticalFg.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unackAlerts > 0 ? '$unackAlerts CẦN XỬ LÝ' : 'AN TOÀN',
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
              _StatItem(
                label: 'Tổng cảnh báo',
                value: '$totalAlerts',
                active: true,
              ),
              _StatItem(
                label: 'Nguy hiểm',
                value: '$criticalAlerts',
                active: criticalAlerts > 0,
                color: BrandTokens.darkCriticalFg,
              ),
              _StatItem(
                label: 'Cảnh báo',
                value: '$warningAlerts',
                active: warningAlerts > 0,
                color: BrandTokens.darkMediumFg,
              ),
              _StatItem(
                label: 'Chưa xử lý',
                value: '$unackAlerts',
                active: unackAlerts > 0,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.active,
    this.color,
  });

  final String label;
  final String value;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color ?? (active ? Colors.white : Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? (isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : (isDark ? BrandTokens.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : (isDark ? BrandTokens.darkBorder : BrandTokens.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : (isDark ? BrandTokens.darkTextPrimary : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? BrandTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(
          color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shield_rounded,
            size: 48,
            color: BrandTokens.stitchSafe,
          ),
          const SizedBox(height: 14),
          Text(
            'Hệ thống an toàn, không có cảnh báo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? BrandTokens.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Raspberry Pi 5 và AI Hailo-8L đang giám sát trực tiếp liên tục.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? BrandTokens.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSystemState extends StatelessWidget {
  const _NoSystemState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_outlined, size: 54, color: AppColors.textTertiary),
            SizedBox(height: 14),
            Text(
              'Chưa có hệ thống IGNIVO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 7),
            Text(
              'Hãy kết nối Edge Box để theo dõi các cảnh báo khẩn cấp.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
