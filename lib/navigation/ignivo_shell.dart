import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/app_auth_controller.dart';
import '../../core/services/camera_snapshot_loader.dart';
import '../../core/services/multi_system_monitoring_coordinator.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/services/system_session_manager.dart';
import '../../core/theme/brand_tokens.dart';
import '../features/activity/guard_activity_page.dart';
import '../features/camera/camera_live_page.dart';
import '../features/camera/guard_cameras_page.dart';
import '../features/fireguard/guard_home_page.dart';
import '../features/fireguard/monitoring_controller.dart';
import '../features/fireguard/incident_page.dart';
import '../features/settings/guard_settings_page.dart';
import '../features/settings/diagnostics_page.dart';
import '../features/systems/systems_page.dart';
import '../widgets/desktop_top_bar.dart';
import '../widgets/ignivo_page_header.dart';
import '../widgets/ignivo_sheet.dart';
import '../../core/services/face_notification_service.dart';
import '../../core/services/fireeye_api_service.dart';
import '../features/fireguard/eye_events_page.dart';
import '../core/models/push_notification_model.dart';
import '../core/services/messaging_service.dart';
import '../widgets/ignivo_floating_notification_banner.dart';

class IgnivoShell extends StatefulWidget {
  const IgnivoShell({
    super.key,
    required this.sessionController,
    this.sessionManager,
    this.coordinator,
    this.authController,
    this.monitoringController,
  });

  final SystemSessionController sessionController;
  final SystemSessionManager? sessionManager;
  final MultiSystemMonitoringCoordinator? coordinator;
  final AppAuthController? authController;
  final MonitoringController? monitoringController;

  @override
  State<IgnivoShell> createState() => _IgnivoShellState();
}

class _IgnivoShellState extends State<IgnivoShell> with WidgetsBindingObserver {
  late final MonitoringController _monitoring;
  late final CameraSnapshotLoader _snapshotLoader;
  final Set<int> _snackBarAnnounced = {};
  StreamSubscription<CrossSystemIncidentAlert>? _crossAlertSub;
  StreamSubscription<FaceNotificationEvent>? _faceNotificationSub;
  StreamSubscription<IgnivoPushNotification>? _pushReceivedSub;
  StreamSubscription<IgnivoPushNotification>? _notificationOpenedSub;
  FireeyeApiService? _fireeyeApi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapshotLoader = CameraSnapshotLoader(api: widget.sessionController.api);
    _monitoring =
        widget.monitoringController ??
        MonitoringController(api: widget.sessionController.api);
    _monitoring.addListener(_onMonitoringChanged);
    _monitoring.start();

    _fireeyeApi = FireeyeApiService(fireguard: widget.sessionController.api);
    unawaited(FaceNotificationService.instance.initialize(eye: _fireeyeApi));

    // 1. Khởi tạo và lắng nghe thông báo đẩy FCM
    MessagingService.instance.setActiveApi(widget.sessionController.api);
    unawaited(MessagingService.instance.registerWithApi(widget.sessionController.api));
    unawaited(MessagingService.instance.initialize());
    _pushReceivedSub = MessagingService.instance.onPushReceived.listen((push) {
      if (!mounted) return;
      IgnivoFloatingNotificationBanner.show(
        context,
        notification: push,
        onTap: () => _handlePushNotification(push),
      );
    });
    _notificationOpenedSub =
        MessagingService.instance.onNotificationOpened.listen((push) {
      if (!mounted) return;
      _handlePushNotification(push);
    });

    // 2. Lắng nghe sự kiện nhận diện khuôn mặt AI
    _faceNotificationSub =
        FaceNotificationService.instance.onFaceEvent.listen((event) {
      if (!mounted) return;
      final isKnown = event.isKnownPerson;
      final title = isKnown
          ? (event.name != null && event.name!.isNotEmpty
              ? '🟢 Xác nhận: ${event.name} đã có mặt'
              : '🟢 Xác nhận: Người quen đã có mặt')
          : '🚨 Cảnh báo: Phát hiện người lạ!';

      final notif = IgnivoPushNotification(
        id: 'face_${event.id}_${DateTime.now().millisecondsSinceEpoch}',
        category: PushNotificationCategory.faceRecognition,
        title: title,
        body: event.message.isNotEmpty
            ? event.message
            : (isKnown
                ? 'Đã nhận diện người quen an toàn trong vùng quan sát.'
                : 'Phát hiện đối tượng chưa đăng ký trong danh bạ an ninh!'),
        isKnownPerson: isKnown,
        personName: event.name,
        timestamp: DateTime.now(),
      );

      IgnivoFloatingNotificationBanner.show(
        context,
        notification: notif,
        onTap: () {
          if (_fireeyeApi != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EyeEventsPage(eye: _fireeyeApi!),
              ),
            );
          }
        },
      );
    });

    // 3. Lắng nghe cảnh báo cháy liên hệ thống (Cross-System)
    _crossAlertSub = widget.coordinator?.onCrossSystemAlert.listen((alert) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CẢNH BÁO KHẨN CẤP: ${alert.systemName} phát hiện sự cố #${alert.incidentId}!',
          ),
          duration: const Duration(seconds: 15),
          backgroundColor: Colors.red.shade900,
          action: SnackBarAction(
            label: 'Chuyển hệ thống',
            textColor: Colors.yellow,
            onPressed: () async {
              await widget.sessionManager?.switchSystem(alert.systemId);
            },
          ),
        ),
      );
    });
  }

  void _handlePushNotification(IgnivoPushNotification push) {
    if (push.incidentId != null) {
      _openIncident(push.incidentId!);
    } else if (push.category == PushNotificationCategory.faceRecognition) {
      if (_fireeyeApi != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EyeEventsPage(eye: _fireeyeApi!)),
        );
      }
    } else if (push.cameraId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraLivePage(
            cameraId: push.cameraId!,
            api: widget.sessionController.api,
            sessionController: widget.sessionController,
          ),
        ),
      );
    }
  }

  void _onMonitoringChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check for newly announced incidents for visual/haptic toast notification
      for (final id in _monitoring.announcedIncidentIds) {
        if (_snackBarAnnounced.add(id)) {
          // Lấy thông tin chi tiết sự cố thực tế từ monitoring
          Map<String, dynamic>? incidentData;
          if (_monitoring.activeIncident != null && _monitoring.activeIncident!['id'] == id) {
            incidentData = _monitoring.activeIncident;
          } else {
            incidentData = _monitoring.incidents.where((i) => i['id'] == id).firstOrNull;
          }

          final triggerType = (incidentData?['trigger_type'] ?? 'FIRE').toString().toUpperCase();
          final cameraName = incidentData?['camera_name']?.toString();
          final area = incidentData?['area']?.toString();
          final isSim = incidentData?['is_simulation'] == true;
          final severity = (incidentData?['severity'] ?? incidentData?['risk_level'] ?? 'critical').toString().toLowerCase();

          final String title;
          if (isSim) {
            title = '🧪 [MÔ PHỎNG] Báo động cháy thử nghiệm';
          } else if (triggerType == 'SMOKE') {
            title = cameraName != null ? '💨 CẢNH BÁO KHÓI BẤT THƯỜNG ($cameraName)' : '💨 CẢNH BÁO PHÁT HIỆN KHÓI';
          } else {
            title = cameraName != null ? '🔥 PHÁT HIỆN NGỌN LỬA ($cameraName)' : '🔥 BÁO ĐỘNG CHÁY CẤP BÁCH';
          }

          final locationName = area ?? cameraName ?? 'khu vực giám sát';
          final body = 'AI thị giác phát hiện ngọn lửa hoặc khói khẩn cấp tại $locationName [#$id]. Nhấn để mở camera và xác minh ngay lập tức!';

          String? imageUrl;
          if (incidentData != null) {
            final analysisImg = incidentData['analysis_image_url'] as String?;
            if (analysisImg != null && analysisImg.isNotEmpty) {
              imageUrl = analysisImg.startsWith('http')
                  ? analysisImg
                  : '${widget.sessionController.api.baseUrl}$analysisImg';
            }
          }

          final notif = IgnivoPushNotification(
            id: 'incident_$id',
            category: PushNotificationCategory.fireEmergency,
            triggerType: triggerType,
            title: title,
            body: body,
            incidentId: id,
            cameraName: cameraName,
            area: area,
            imageUrl: imageUrl,
            severity: severity,
            isSimulation: isSim,
            timestamp: DateTime.now(),
          );

          IgnivoFloatingNotificationBanner.show(
            context,
            notification: notif,
            onTap: () => _openIncident(id),
          );
        }
      }

      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _monitoring.resume();
      if (_fireeyeApi != null) {
        FaceNotificationService.instance.startListening(_fireeyeApi!);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _monitoring.pause();
      FaceNotificationService.instance.stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _crossAlertSub?.cancel();
    _faceNotificationSub?.cancel();
    _pushReceivedSub?.cancel();
    _notificationOpenedSub?.cancel();
    FaceNotificationService.instance.stopListening();
    _monitoring.removeListener(_onMonitoringChanged);
    if (widget.monitoringController == null) {
      _monitoring.dispose();
    }
    _snapshotLoader.dispose();
    super.dispose();
  }

  int _selectedTab = 0;

  void _openIncident(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FireguardIncidentPage(
          incidentId: id,
          api: _monitoring.api,
          realtime: _monitoring.realtime,
          coordinator: _monitoring.coordinator,
          controller: _monitoring,
        ),
      ),
    );
  }

  void _openCameraLive(int cameraId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraLivePage(
          cameraId: cameraId,
          api: _monitoring.api,
          sessionController: widget.sessionController,
        ),
      ),
    );
  }

  void _openDiagnostics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosticsPage(
          sessionController: widget.sessionController,
          monitoringController: _monitoring,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        final isExtended = constraints.maxWidth >= 1080;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final tabContent = switch (_selectedTab) {
          0 => GuardHomePage(
            sessionController: widget.sessionController,
            sessionManager: widget.sessionManager,
            monitoringController: _monitoring,
            snapshotLoader: _snapshotLoader,
            authController: widget.authController,
            coordinator: widget.coordinator,
            onNavigateTab: (idx) => setState(() => _selectedTab = idx),
            onOpenIncident: _openIncident,
            onOpenLiveView: _openCameraLive,
            onOpenDiagnostics: _openDiagnostics,
          ),
          1 => GuardCamerasPage(
            monitoringController: _monitoring,
            sessionController: widget.sessionController,
            snapshotLoader: _snapshotLoader,
            onOpenLiveView: _openCameraLive,
          ),
          2 => GuardActivityPage(
            monitoringController: _monitoring,
            sessionController: widget.sessionController,
            onOpenIncident: _openIncident,
          ),
          3 => GuardSettingsPage(
            sessionController: widget.sessionController,
            monitoringController: _monitoring,
            sessionManager: widget.sessionManager,
            authController: widget.authController,
            coordinator: widget.coordinator,
            onOpenDiagnostics: _openDiagnostics,
          ),
          _ => const SizedBox.shrink(),
        };

        final unclosedIncidents = _monitoring.incidents.where((inc) {
          final s = inc['status'];
          return s != 'resolved' && s != 'false_alarm';
        }).toList();
        final unclosedCount = unclosedIncidents.length;
        final hasUrgent = unclosedIncidents.any((inc) {
          final s = inc['status'];
          final sev = inc['severity']?.toString().toLowerCase();
          return s == 'analyzing' ||
              s == 'notifying' ||
              sev == 'critical' ||
              sev == 'high';
        });

        Widget buildAlertNavIcon({required bool isSelected}) {
          final icon = Icon(
            isSelected ? Icons.warning_rounded : Icons.warning_amber_rounded,
          );
          if (unclosedCount <= 0) return icon;
          return Badge.count(
            count: unclosedCount,
            backgroundColor: hasUrgent
                ? BrandTokens.stitchCriticalFg
                : BrandTokens.stitchWarningFg,
            textColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            child: icon,
          );
        }

        final Widget shellScaffold = !isDesktop
            ? Scaffold(
                body: tabContent,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (idx) => setState(() => _selectedTab = idx),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Trang chủ',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.videocam_outlined),
                      selectedIcon: Icon(Icons.videocam),
                      label: 'Camera',
                    ),
                    NavigationDestination(
                      icon: buildAlertNavIcon(isSelected: false),
                      selectedIcon: buildAlertNavIcon(isSelected: true),
                      label: 'Cảnh báo',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Cài đặt',
                    ),
                  ],
                ),
              )
            : Scaffold(
                body: Row(
            children: [
              NavigationRail(
                extended: isExtended,
                labelType: isExtended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: _selectedTab,
                onDestinationSelected: (idx) =>
                    setState(() => _selectedTab = idx),
                backgroundColor:
                    isDark ? BrandTokens.darkSurface : BrandTokens.surface,
                minExtendedWidth: 200,
                leading: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isExtended ? 20 : 16,
                    horizontal: isExtended ? 16 : 8,
                  ),
                  child: isExtended
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              BrandTokens.markAsset,
                              height: 34,
                              width: 34,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.local_fire_department_rounded,
                                color: BrandTokens.brandPrimary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'IGNIVO',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 2.0,
                                color: BrandTokens.brandPrimary,
                              ),
                            ),
                          ],
                        )
                      : Image.asset(
                          BrandTokens.markAsset,
                          height: 32,
                          width: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.local_fire_department_rounded,
                            color: BrandTokens.brandPrimary,
                            size: 30,
                          ),
                        ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(BrandTokens.badgeRadius),
                        onTap: widget.sessionManager != null
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SystemsPage(
                                      sessionManager: widget.sessionManager!,
                                      authController: widget.authController,
                                      coordinator: widget.coordinator,
                                      canPop: true,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: isExtended
                            ? Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? BrandTokens.darkBrandTint
                                          : BrandTokens.brandTint)
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(
                                    BrandTokens.badgeRadius,
                                  ),
                                  border: Border.all(
                                    color: (isDark
                                            ? BrandTokens.darkBorder
                                            : BrandTokens.border)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cloud_done_rounded,
                                      size: 16,
                                      color: _monitoring.stale
                                          ? Colors.amber
                                          : BrandTokens.stitchSafe,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        widget.sessionController.systemName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Tooltip(
                                message: widget.sessionController.systemName,
                                child: Icon(
                                  Icons.cloud_done_rounded,
                                  size: 20,
                                  color: _monitoring.stale
                                      ? Colors.amber
                                      : BrandTokens.stitchSafe,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Trang chủ'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.videocam_outlined),
                    selectedIcon: Icon(Icons.videocam),
                    label: Text('Camera'),
                  ),
                  NavigationRailDestination(
                    icon: buildAlertNavIcon(isSelected: false),
                    selectedIcon: buildAlertNavIcon(isSelected: true),
                    label: const Text('Cảnh báo'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Cài đặt'),
                  ),
                ],
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? BrandTokens.darkBorder : BrandTokens.border,
              ),
              Expanded(
                child: Column(
                  children: [
                    DesktopTopBar(
                      title: switch (_selectedTab) {
                        0 => 'Trung tâm Giám sát',
                        1 => 'Quản lý Camera',
                        2 => 'Nhật ký & Cảnh báo',
                        3 => 'Cài đặt Hệ thống',
                        _ => 'IGNIVO',
                      },
                      systemName: widget.sessionController.systemName,
                      role: widget.sessionController.role,
                      isWsConnected: _monitoring.isWsConnected,
                      isStale: _monitoring.stale,
                      onRefresh: () async {
                        _snapshotLoader.clearCache();
                        await _monitoring.refresh();
                      },
                      onOpenDiagnostics: _openDiagnostics,
                      onTapSystem: () {
                        if (widget.sessionManager != null) {
                          showIgnivoQuickSystemSwitcherSheet(
                            context: context,
                            sessionManager: widget.sessionManager!,
                            onOpenSystemsPage: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SystemsPage(
                                    sessionManager: widget.sessionManager!,
                                    authController: widget.authController,
                                    coordinator: widget.coordinator,
                                    canPop: true,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                    Expanded(
                      child: IgnivoDesktopTopBarScope(
                        hasTopBar: true,
                        child: tabContent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        return PopScope(
          canPop: _selectedTab == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectedTab != 0) {
              setState(() => _selectedTab = 0);
            }
          },
          child: shellScaffold,
        );
      },
    );
  }
}
