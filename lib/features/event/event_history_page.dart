import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
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

    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Lịch sử Sự kiện',
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
            return const Center(child: Text('Chưa kết nối IGNIVO Edge Box.'));
          }

          final selectedSystem = systems.firstWhere(
                (sys) => sys.id == _selectedSystemId,
            orElse: () => systems.first,
          );

          return Column(
            children: [
              // System filter chip
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

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.watchEvents(selectedSystem.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = snapshot.data?.docs
                        .map((doc) => EventModel.fromFirestore(doc, systemId: selectedSystem.id))
                        .toList() ??
                        [];

                    if (events.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có sự kiện nào được ghi nhận.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return _EventCard(event: event);
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

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              if (event.createdAt != null)
                Text(
                  DateFormat('HH:mm:ss - dd/MM/yyyy').format(event.createdAt!),
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
            ],
          ),
          if (event.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.summary,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
