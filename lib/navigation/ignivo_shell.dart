import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/system_session_controller.dart';
import '../features/fireguard/fireguard_page.dart';
import '../features/fireguard/monitoring_controller.dart';
import '../features/fireguard/incident_page.dart';

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

  @override
  Widget build(BuildContext context) {
    // In Package 2, wrap FireguardPage to maintain full feature compatibility while
    // delegating session & monitoring control to the unified Shell/Controllers.
    // In Packages 3-6, each tab will be replaced with its dedicated page (GuardHomePage, etc.).
    return Scaffold(
      body: FireguardPage(
        api: _monitoring.api,
        realtime: _monitoring.realtime,
        coordinator: _monitoring.coordinator,
      ),
    );
  }
}
