import 'pi_connection_profile.dart';

/// Đại diện cho một hệ thống Edge Box (Raspberry Pi) được liên kết với tài khoản Ignivo.
class SystemRecord {
  const SystemRecord({
    required this.systemId,
    required this.systemName,
    required this.guardUrl,
    this.eyeUrl = '',
    this.location = '',
    this.deviceId,
    this.isOwner = true,
    this.role = 'OWNER',
    this.configVersion = 1,
    required this.addedAt,
    this.lastConnectedAt,
    this.status = 'unverified',
  });

  final String systemId;
  final String systemName;
  final String guardUrl;
  final String eyeUrl;
  final String location;
  final String? deviceId;
  final bool isOwner;
  final String role;
  final int configVersion;
  final DateTime addedAt;
  final DateTime? lastConnectedAt;
  final String status;

  SystemRecord copyWith({
    String? systemId,
    String? systemName,
    String? guardUrl,
    String? eyeUrl,
    String? location,
    String? deviceId,
    bool? isOwner,
    String? role,
    int? configVersion,
    DateTime? addedAt,
    DateTime? lastConnectedAt,
    String? status,
  }) {
    return SystemRecord(
      systemId: systemId ?? this.systemId,
      systemName: systemName ?? this.systemName,
      guardUrl: guardUrl ?? this.guardUrl,
      eyeUrl: eyeUrl ?? this.eyeUrl,
      location: location ?? this.location,
      deviceId: deviceId ?? this.deviceId,
      isOwner: isOwner ?? this.isOwner,
      role: role ?? this.role,
      configVersion: configVersion ?? this.configVersion,
      addedAt: addedAt ?? this.addedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'system_id': systemId,
    'system_name': systemName,
    'guard_url': guardUrl,
    'eye_url': eyeUrl,
    'location': location,
    'device_id': deviceId,
    'is_owner': isOwner,
    'role': role,
    'config_version': configVersion,
    'added_at': addedAt.toIso8601String(),
    'last_connected_at': lastConnectedAt?.toIso8601String(),
    'status': status,
  };

  factory SystemRecord.fromJson(Map<String, dynamic> json) {
    return SystemRecord(
      systemId: json['system_id']?.toString() ?? '',
      systemName: json['system_name']?.toString() ?? 'Hệ thống Ignivo',
      guardUrl: json['guard_url']?.toString() ?? '',
      eyeUrl: json['eye_url']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      deviceId: json['device_id']?.toString(),
      isOwner: json['is_owner'] as bool? ?? true,
      role: json['role']?.toString() ?? 'OWNER',
      configVersion: (json['config_version'] as num?)?.toInt() ?? 1,
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastConnectedAt: json['last_connected_at'] != null
          ? DateTime.tryParse(json['last_connected_at'].toString())
          : null,
      status: json['status']?.toString() ?? 'unverified',
    );
  }

  /// Chuyển đổi sang PiConnectionProfile để tương thích với các module cũ
  PiConnectionProfile toPiConnectionProfile() {
    final uri = Uri.tryParse(guardUrl);
    final host = uri?.host ?? '';
    return PiConnectionProfile(
      systemName: systemName,
      piHost: host,
      eyeUrl: eyeUrl.isNotEmpty ? eyeUrl : 'http://$host:8000',
      guardUrl: guardUrl,
      isConfigured: guardUrl.isNotEmpty,
      deviceId: deviceId,
      isCustomAdvanced: eyeUrl.isNotEmpty,
      version: 3,
    );
  }

  /// Khởi tạo SystemRecord từ PiConnectionProfile cũ
  static SystemRecord fromPiConnectionProfile(
    PiConnectionProfile profile, {
    String? systemId,
    String? location,
  }) {
    final id = systemId ??
        (profile.deviceId != null && profile.deviceId!.isNotEmpty
            ? 'sys_${profile.deviceId}'
            : 'sys_${DateTime.now().millisecondsSinceEpoch}');
    return SystemRecord(
      systemId: id,
      systemName: profile.systemName,
      guardUrl: profile.guardUrl,
      eyeUrl: profile.eyeUrl,
      location: location ?? '',
      deviceId: profile.deviceId,
      isOwner: true,
      role: 'OWNER',
      configVersion: 1,
      addedAt: DateTime.now(),
      lastConnectedAt: DateTime.now(),
      status: 'connected',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemRecord &&
          runtimeType == other.runtimeType &&
          systemId == other.systemId;

  @override
  int get hashCode => systemId.hashCode;
}
