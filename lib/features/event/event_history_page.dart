import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_tokens.dart';
import '../../models/event_model.dart';
import '../../models/system_model.dart';

class EventHistoryPage extends StatefulWidget {
  const EventHistoryPage({super.key});

  @override
  State<EventHistoryPage> createState() => _EventHistoryPageState();
}

class _EventHistoryPageState extends State<EventHistoryPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String? _selectedSystemId;

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
          'Lịch sử Sự kiện',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
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
            return const Center(
              child: Text('Chưa kết nối IGNIVO Edge Box.'),
            );
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
                  stream: _firestoreService.watchEvents(selectedSystem.id),
                  builder: (context, snapshot) {
                    final events = snapshot.data?.docs
                            .map((doc) => EventModel.fromFirestore(doc, systemId: selectedSystem.id))
                            .toList() ??
                        [];

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
                                'Tổng quan Lịch sử',
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
                                'Ghi nhận toàn bộ hoạt động hệ thống, AI triggers và thao tác vận hành.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? BrandTokens.darkTextTertiary
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // System Event Summary Card (Home Page format)
                              _EventSummaryCard(
                                system: selectedSystem,
                                eventCount: events.length,
                              ),

                              const SizedBox(height: 24),

                              Text(
                                'Danh sách Sự kiện',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? BrandTokens.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (snapshot.connectionState == ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (events.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
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
                                        Icons.history_toggle_off_rounded,
                                        size: 42,
                                        color: AppColors.textTertiary,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Chưa có sự kiện nào được ghi nhận',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? BrandTokens.darkTextPrimary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: events.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final event = events[index];
                                    return _EventCard(event: event);
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

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.system,
    required this.eventCount,
  });

  final IgnivoSystem system;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: BrandTokens.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandTokens.brandNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: Colors.white, size: 26),
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
                  'Tổng số $eventCount sự kiện đã lưu',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$eventCount Events',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? BrandTokens.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (event.createdAt != null)
                Text(
                  DateFormat('HH:mm:ss • dd/MM/yyyy').format(event.createdAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? BrandTokens.darkTextTertiary : AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (event.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? BrandTokens.darkSurfaceVariant.withValues(alpha: 0.5)
                    : BrandTokens.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                event.summary,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? BrandTokens.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
