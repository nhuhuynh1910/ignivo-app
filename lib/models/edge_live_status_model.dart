class EdgeLiveStatus {
  const EdgeLiveStatus({
    this.online = false,
    this.aiOnline = false,
    this.internetAvailable = false,
    this.powerAvailable = true,
    this.safetyStatus = 'NORMAL',
    this.lastSeen,
  });

  final bool online;
  final bool aiOnline;
  final bool internetAvailable;
  final bool powerAvailable;
  final String safetyStatus;
  final DateTime? lastSeen;

  factory EdgeLiveStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const EdgeLiveStatus();
    }

    final rawLastSeen = map['lastSeen'];
    DateTime? lastSeenDate;
    if (rawLastSeen is int) {
      lastSeenDate = DateTime.fromMillisecondsSinceEpoch(rawLastSeen);
    }

    return EdgeLiveStatus(
      online: map['online'] == true,
      aiOnline: map['aiOnline'] == true,
      internetAvailable: map['internetAvailable'] == true,
      powerAvailable: map['powerAvailable'] != false,
      safetyStatus: map['safetyStatus']?.toString() ?? 'NORMAL',
      lastSeen: lastSeenDate,
    );
  }
}
