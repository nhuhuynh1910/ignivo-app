import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'fireguard_api_service.dart';

enum FireguardConnection {
  stopped,
  connecting,
  connected,
  reconnecting,
  expired,
}

class FireguardEvent {
  const FireguardEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
  int? get incidentId =>
      (name == 'call.updated' ? data['incident_id'] : data['id']) as int?;
}

/// One foreground connection, shared by the dashboard and incident details.
class FireguardRealtimeService extends ChangeNotifier {
  FireguardRealtimeService(
    this.api, {
    this.retryDelay = const Duration(seconds: 2),
  }) {
    _session = api.sessionChanges.listen((_) {
      if (!_enabled) return;
      _reset();
      _connect();
    });
  }
  final FireguardApiService api;
  final Duration retryDelay;
  final _events = StreamController<FireguardEvent>.broadcast();
  Stream<FireguardEvent> get events => _events.stream;
  FireguardConnection state = FireguardConnection.stopped;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _messages;
  late final StreamSubscription<void> _session;
  Timer? _retry, _ping;
  int _generation = 0, _attempt = 0;
  bool _enabled = false, _disposed = false;

  void _state(FireguardConnection value) {
    if (_disposed || state == value) return;
    state = value;
    notifyListeners();
  }

  void start() {
    if (_disposed || _enabled) return;
    _enabled = true;
    _attempt = 0;
    _connect();
  }

  void stop() {
    _enabled = false;
    _reset();
    _state(FireguardConnection.stopped);
  }

  void _reset() {
    _generation++;
    _retry?.cancel();
    _ping?.cancel();
    _messages?.cancel();
    _messages = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      // A failed handshake may also complete the sink with an error.
      unawaited(
        channel.sink.close().then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  Future<void> _connect() async {
    if (!_enabled || _disposed) return;
    if (api.authToken == null) {
      _state(FireguardConnection.expired);
      return;
    }
    final generation = ++_generation;
    _state(
      _attempt == 0
          ? FireguardConnection.connecting
          : FireguardConnection.reconnecting,
    );
    try {
      final channel = WebSocketChannel.connect(api.websocketUri);
      _channel = channel;
      _messages = channel.stream.listen(
        (message) {
          if (generation != _generation || message is! String) return;
          try {
            final value = jsonDecode(message);
            if (value is! Map || value['data'] is! Map<String, dynamic>) return;
            final name = value['event'];
            if (!const [
              'incident.created',
              'incident.updated',
              'incident.analyzed',
              'incident.closed',
              'call.updated',
            ].contains(name)) {
              return;
            }
            final event = FireguardEvent(
              name as String,
              value['data'] as Map<String, dynamic>,
            );
            if (event.incidentId != null) _events.add(event);
          } catch (_) {
            // Ignore malformed/unknown frames without dropping valid later events.
          }
        },
        onError: (Object _) => _disconnected(generation),
        onDone: () => _disconnected(generation, code: channel.closeCode),
      );
      await channel.ready.timeout(const Duration(seconds: 12));
      if (generation != _generation) return;
      _attempt = 0;
      _state(FireguardConnection.connected);
      _ping = Timer.periodic(const Duration(seconds: 20), (_) {
        if (generation == _generation) channel.sink.add('ping');
      });
    } catch (_) {
      // Do not surface transport errors: they may contain the token-bearing URI.
      await _disconnected(generation);
    }
  }

  Future<void> _disconnected(int generation, {int? code}) async {
    if (generation != _generation || !_enabled || _disposed) return;
    _reset();
    final recovery = _generation;
    _state(FireguardConnection.reconnecting);
    if (code == 4401) {
      try {
        if (await (api.renewSession?.call() ?? Future.value(false))) return;
        await api.setAuthToken(null);
        return;
      } catch (_) {
        // A temporary network failure must not destroy a refreshable session.
      }
    }
    // FastAPI can reject auth before accepting WS (HTTP 403 instead of 4401).
    try {
      await api.getCurrentUser();
    } catch (_) {
      // HTTP 401 clears the shared session; network failures are retried.
    }
    if (recovery != _generation || !_enabled || _disposed) return;
    if (api.authToken == null) {
      _state(FireguardConnection.expired);
      return;
    }
    final multiplier = 1 << _attempt.clamp(0, 4);
    _attempt++;
    _retry = Timer(retryDelay * multiplier, _connect);
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    _session.cancel();
    _events.close();
    super.dispose();
  }
}
