import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/camera_snapshot_loader.dart';
import '../../core/services/system_session_controller.dart';
import '../../core/theme/brand_tokens.dart';
import '../features/activity/guard_activity_page.dart';
import '../features/camera/camera_live_page.dart';
import '../features/camera/guard_cameras_page.dart';
import '../features/fireguard/guard_home_page.dart';
import '../features/fireguard/monitoring_controller.dart';
import '../features/fireguard/incident_page.dart';
import '../features/settings/guard_settings_page.dart';
import '../features/settings/diagnostics_page.dart';
import '../widgets/desktop_top_bar.dart';

class IgnivoShell extends StatefulWidget {
  const IgnivoShell({
    super.key,
    required this.sessionController,
    this.monitoringController,
  });

  final SystemSessionController sessionController;
  final MonitoringController? monitoringController;

  @override
  State<IgnivoShell> createState() => _IgnivoShellState();
}

class _IgnivoShellState extends State<IgnivoShell> with WidgetsBindingObserver {
  late final MonitoringController _monitoring;
  late final CameraSnapshotLoader _snapshotLoader;
  final Set<int> _snackBarAnnounced = {};

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
  }

  void _onMonitoringChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check for newly announced incidents for visual/haptic toast notification
      for (final id in _monitoring.announcedIncidentIds) {
        if (_snackBarAnnounced.add(id)) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CẢNH BÁO: Phát hiện sự cố mới #$id'),
              duration: const Duration(seconds: 15),
              backgroundColor: Colors.red.shade900,
              action: SnackBarAction(
                label: 'Xem',
                textColor: Colors.yellow,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FireguardIncidentPage(
                        incidentId: id,
                        api: _monitoring.api,
                        realtime: _monitoring.realtime,
                        coordinator: _monitoring.coordinator,
                      ),
                    ),
                  );
                },
              ),
            ),
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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _monitoring.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            monitoringController: _monitoring,
            snapshotLoader: _snapshotLoader,
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
            onOpenDiagnostics: _openDiagnostics,
          ),
          _ => const SizedBox.shrink(),
        };

        if (!isDesktop) {
          return Scaffold(
            body: tabContent,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (idx) => setState(() => _selectedTab = idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.videocam_outlined),
                  selectedIcon: Icon(Icons.videocam),
                  label: 'Camera',
                ),
                NavigationDestination(
                  icon: Icon(Icons.warning_amber_rounded),
                  selectedIcon: Icon(Icons.warning_rounded),
                  label: 'Cảnh báo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Cài đặt',
                ),
              ],
            ),
          );
        }

        return Scaffold(
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
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Trang chủ'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.videocam_outlined),
                    selectedIcon: Icon(Icons.videocam),
                    label: Text('Camera'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.warning_amber_rounded),
                    selectedIcon: Icon(Icons.warning_rounded),
                    label: Text('Cảnh báo'),
                  ),
                  NavigationRailDestination(
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
                    ),
                    Expanded(child: tabContent),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
