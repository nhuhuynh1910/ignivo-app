import 'package:firebase_messaging/firebase_messaging.dart';

/// Phân loại danh mục thông báo đẩy trong hệ thống IGNIVO
enum PushNotificationCategory {
  /// Cảnh báo cháy, ngọn lửa, khói, nhiệt độ bất thường (Mức độ cao nhất)
  fireEmergency,

  /// Nhận diện khuôn mặt AI (Người quen / Cảnh báo người lạ)
  faceRecognition,

  /// Trạng thái kết nối Edge Box, pin, camera offline
  systemNotice,

  /// Thông báo chung (lời mời thành viên, cập nhật phần mềm)
  general,
}

/// Model chuẩn hóa dữ liệu thông báo đẩy FCM của IGNIVO
class IgnivoPushNotification {
  const IgnivoPushNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.rawTitle,
    this.rawBody,
    this.triggerType,
    this.imageUrl,
    this.severity,
    this.incidentId,
    this.cameraId,
    this.cameraName,
    this.area,
    this.confidence,
    this.isSimulation = false,
    this.personName,
    this.isKnownPerson,
    required this.timestamp,
    this.data = const {},
  });

  final String id;
  final PushNotificationCategory category;
  final String title;
  final String body;
  final String? rawTitle;
  final String? rawBody;
  final String? triggerType;
  final String? imageUrl;
  final String? severity;
  final int? incidentId;
  final int? cameraId;
  final String? cameraName;
  final String? area;
  final double? confidence;
  final bool isSimulation;
  final String? personName;
  final bool? isKnownPerson;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  /// Chuyển đổi từ RemoteMessage của Firebase Cloud Messaging sang Model chuẩn
  factory IgnivoPushNotification.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notif = message.notification;

    final rawTitle = notif?.title ?? data['title']?.toString();
    final rawBody = notif?.body ?? data['body']?.toString() ?? data['message']?.toString();

    // Tìm URL ảnh từ notification payload hoặc data payload
    final imageUrl = notif?.android?.imageUrl ??
        notif?.apple?.imageUrl ??
        data['image_url']?.toString() ??
        data['analysis_image_url']?.toString() ??
        data['snapshot_url']?.toString();

    final typeStr = (data['type'] ?? data['event_type'] ?? data['trigger_type'] ?? '').toString().toLowerCase();
    final triggerType = (data['trigger_type'] ?? data['trigger'] ?? '').toString().toUpperCase();
    final severity = (data['severity'] ?? data['risk_level'] ?? data['level'] ?? '').toString().toLowerCase();
    final incidentId = int.tryParse(data['incident_id']?.toString() ?? data['id']?.toString() ?? '');
    final cameraId = int.tryParse(data['camera_id']?.toString() ?? '');
    final cameraName = data['camera_name']?.toString() ?? data['camera']?.toString();
    final area = data['area']?.toString() ?? data['room']?.toString();
    final isSimulation = data['is_simulation'] == true ||
        data['is_simulation']?.toString() == 'true' ||
        data['is_simulation']?.toString() == '1';
    final confidence = double.tryParse(data['confidence']?.toString() ?? '');
    final personName = data['person_name']?.toString() ?? data['name']?.toString();
    final isKnown = data['is_known'] != null
        ? (data['is_known'] == true || data['is_known'].toString() == 'true' || data['is_known'].toString() == '1')
        : (typeStr == 'known_person' ? true : (typeStr == 'unknown_person' ? false : null));

    // Xác định phân loại thông báo
    final PushNotificationCategory category;
    if (triggerType == 'FIRE' ||
        triggerType == 'SMOKE' ||
        typeStr.contains('fire') ||
        typeStr.contains('incident') ||
        typeStr.contains('smoke') ||
        incidentId != null ||
        severity == 'critical' ||
        severity == 'high') {
      category = PushNotificationCategory.fireEmergency;
    } else if (typeStr.contains('face') ||
        typeStr.contains('person') ||
        personName != null ||
        isKnown != null) {
      category = PushNotificationCategory.faceRecognition;
    } else if (typeStr.contains('system') ||
        typeStr.contains('device') ||
        typeStr.contains('offline') ||
        typeStr.contains('edge')) {
      category = PushNotificationCategory.systemNotice;
    } else {
      category = PushNotificationCategory.general;
    }

    // Làm đẹp tiêu đề (Decorated Title)
    final formattedTitle = _beautifyTitle(
      category: category,
      rawTitle: rawTitle,
      triggerType: triggerType,
      severity: severity,
      cameraName: cameraName,
      area: area,
      isSimulation: isSimulation,
      isKnownPerson: isKnown,
      personName: personName,
    );

    // Làm đẹp nội dung (Decorated Body)
    final formattedBody = _beautifyBody(
      category: category,
      rawBody: rawBody,
      triggerType: triggerType,
      cameraName: cameraName,
      area: area,
      incidentId: incidentId,
      confidence: confidence,
      isSimulation: isSimulation,
      personName: personName,
      isKnownPerson: isKnown,
    );

    return IgnivoPushNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      title: formattedTitle,
      body: formattedBody,
      rawTitle: rawTitle,
      rawBody: rawBody,
      triggerType: triggerType.isNotEmpty ? triggerType : (category == PushNotificationCategory.fireEmergency ? 'FIRE' : null),
      imageUrl: imageUrl,
      severity: severity.isNotEmpty ? severity : null,
      incidentId: incidentId,
      cameraId: cameraId,
      cameraName: cameraName,
      area: area,
      confidence: confidence,
      isSimulation: isSimulation,
      personName: personName,
      isKnownPerson: isKnown,
      timestamp: message.sentTime ?? DateTime.now(),
      data: data,
    );
  }

  static String _beautifyTitle({
    required PushNotificationCategory category,
    required String? rawTitle,
    required String triggerType,
    required String severity,
    required String? cameraName,
    required String? area,
    required bool isSimulation,
    required bool? isKnownPerson,
    required String? personName,
  }) {
    if (rawTitle != null && rawTitle.trim().isNotEmpty) {
      final trimmed = rawTitle.trim();
      if (trimmed.startsWith('🔥') ||
          trimmed.startsWith('🚨') ||
          trimmed.startsWith('🟢') ||
          trimmed.startsWith('💨') ||
          trimmed.startsWith('🧪') ||
          trimmed.startsWith('🛡️')) {
        return trimmed;
      }
      switch (category) {
        case PushNotificationCategory.fireEmergency:
          return triggerType == 'SMOKE' ? '💨 $trimmed' : '🔥 $trimmed';
        case PushNotificationCategory.faceRecognition:
          return (isKnownPerson ?? false) ? '🟢 $trimmed' : '🟠 $trimmed';
        case PushNotificationCategory.systemNotice:
          return '⚙️ $trimmed';
        case PushNotificationCategory.general:
          return '🛡️ $trimmed';
      }
    }

    final location = (area != null && area.isNotEmpty)
        ? area
        : (cameraName != null && cameraName.isNotEmpty ? cameraName : null);

    switch (category) {
      case PushNotificationCategory.fireEmergency:
        if (isSimulation) {
          return location != null
              ? '🧪 [MÔ PHỎNG] BÁO ĐỘNG CHÁY ($location)'
              : '🧪 [MÔ PHỎNG] BÁO ĐỘNG CHÁY THỬ NGHIỆM';
        }
        if (triggerType == 'SMOKE') {
          return location != null
              ? '💨 CẢNH BÁO PHÁT HIỆN KHÓI ($location)'
              : '💨 CẢNH BÁO PHÁT HIỆN KHÓI BẤT THƯỜNG';
        }
        final prefix = severity == 'critical'
            ? '🔥 BÁO ĐỘNG CHÁY CẤP BÁCH'
            : '🔥 PHÁT HIỆN NGỌN LỬA';
        return location != null ? '$prefix ($location)' : prefix;

      case PushNotificationCategory.faceRecognition:
        if (isKnownPerson == true) {
          return personName != null && personName.isNotEmpty
              ? '🟢 Người quen: $personName'
              : '🟢 Nhận diện người quen';
        } else {
          return '🟠 Khuôn mặt chưa khớp (Cần xác minh)';
        }

      case PushNotificationCategory.systemNotice:
        return '⚙️ Thông báo hệ thống Edge Box';

      case PushNotificationCategory.general:
        return '🛡️ Thông báo an ninh IGNIVO';
    }
  }

  static String _beautifyBody({
    required PushNotificationCategory category,
    required String? rawBody,
    required String triggerType,
    required String? cameraName,
    required String? area,
    required int? incidentId,
    required double? confidence,
    required bool isSimulation,
    required String? personName,
    required bool? isKnownPerson,
  }) {
    if (rawBody != null && rawBody.trim().isNotEmpty) {
      return rawBody.trim();
    }

    final locationParts = <String>[];
    if (area != null && area.isNotEmpty) locationParts.add(area);
    if (cameraName != null && cameraName.isNotEmpty && cameraName != area) {
      locationParts.add(cameraName);
    }
    final loc = locationParts.isNotEmpty ? 'tại ${locationParts.join(' • ')}' : 'trong khu vực giám sát';
    final idText = incidentId != null ? ' [#$incidentId]' : '';
    final confText = confidence != null ? ' (Độ tin cậy: ${(confidence * 100).toInt()}%)' : '';

    switch (category) {
      case PushNotificationCategory.fireEmergency:
        if (isSimulation) {
          return 'Mô phỏng kích hoạt còi hú và kiểm tra camera an ninh $loc$idText. Không có nguy hiểm thực tế.';
        }
        if (triggerType == 'SMOKE') {
          return 'Cảm biến AI phát hiện mật độ khói vượt mức an toàn $loc$idText$confText. Nhấn để kiểm tra camera ngay lập tức!';
        }
        return 'AI thị giác phát hiện ngọn lửa bốc lên $loc$idText$confText. Nhấn để mở camera và xác minh khẩn cấp!';

      case PushNotificationCategory.faceRecognition:
        if (isKnownPerson == true) {
          final name = personName ?? 'Người quen';
          return 'Đã xác nhận sự có mặt của $name $loc an toàn.';
        } else {
          return 'Khuôn mặt chưa khớp danh sách đăng ký $loc. Chỉ hỗ trợ xác minh.';
        }

      case PushNotificationCategory.systemNotice:
        return 'Hệ thống an ninh IGNIVO ghi nhận thay đổi trạng thái hoạt động.';

      case PushNotificationCategory.general:
        return 'Nhấn để mở ứng dụng IGNIVO và xem chi tiết thông tin.';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category.name,
    'title': title,
    'body': body,
    'raw_title': rawTitle,
    'raw_body': rawBody,
    'trigger_type': triggerType,
    'image_url': imageUrl,
    'severity': severity,
    'incident_id': incidentId,
    'camera_id': cameraId,
    'camera_name': cameraName,
    'area': area,
    'confidence': confidence,
    'is_simulation': isSimulation,
    'person_name': personName,
    'is_known_person': isKnownPerson,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
  };

  factory IgnivoPushNotification.fromMap(Map<String, dynamic> map) {
    return IgnivoPushNotification(
      id: map['id']?.toString() ?? '',
      category: PushNotificationCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => PushNotificationCategory.general,
      ),
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      rawTitle: map['raw_title']?.toString(),
      rawBody: map['raw_body']?.toString(),
      triggerType: map['trigger_type']?.toString(),
      imageUrl: map['image_url']?.toString(),
      severity: map['severity']?.toString(),
      incidentId: map['incident_id'] is int
          ? map['incident_id'] as int
          : int.tryParse(map['incident_id']?.toString() ?? ''),
      cameraId: map['camera_id'] is int
          ? map['camera_id'] as int
          : int.tryParse(map['camera_id']?.toString() ?? ''),
      cameraName: map['camera_name']?.toString(),
      area: map['area']?.toString(),
      confidence: map['confidence'] != null
          ? double.tryParse(map['confidence'].toString())
          : null,
      isSimulation: map['is_simulation'] == true ||
          map['is_simulation']?.toString() == 'true',
      personName: map['person_name']?.toString(),
      isKnownPerson: map['is_known_person'] != null
          ? map['is_known_person'] == true ||
              map['is_known_person']?.toString() == 'true'
          : null,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const {},
    );
  }
}
