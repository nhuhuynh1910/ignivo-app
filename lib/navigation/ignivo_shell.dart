import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/system_session_controller.dart';
import '../features/activity/guard_activity_page.dart';
import '../features/camera/camera_live_page.dart';
import '../features/camera/guard_cameras_page.dart';
import '../features/fireguard/guard_home_page.dart';
import '../features/fireguard/monitoring_controller.dart';
import '../features/fireguard/incident_page.dart';
import '../features/settings/guard_settings_page.dart';

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

class _IgnivoShellState extends State<IgnivoShell>
    with WidgetsBindingObserver {
  late final MonitoringController _monitoring;
  final Set<int> _snackBarAnnounced = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _monitoring = widget.monitoringController ??
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
    setState(() => _selectedTab = 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_selectedTab) {
        0 => GuardHomePage(
          sessionController: widget.sessionController,
          monitoringController: _monitoring,
          onNavigateTab: (idx) => setState(() => _selectedTab = idx),
          onOpenIncident: _openIncident,
          onOpenLiveView: _openCameraLive,
          onOpenDiagnostics: _openDiagnostics,
        ),
        1 => GuardCamerasPage(
          monitoringController: _monitoring,
          sessionController: widget.sessionController,
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
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (idx) => setState(() => _selectedTab = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Giám sát',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Hoạt động',
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
}
