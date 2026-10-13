import 'dart:async';

enum StreamState {
  connecting,
  live,
  reconnecting,
  offline,
  error,
}

class CameraStreamService {
  /// Request WebRTC Live Video Session from Raspberry Pi 5
  Future<String> requestLiveSession({
    required String systemId,
    required String cameraId,
    required String streamId,
  }) async {
    // WebRTC signaling exchange with RPi5 via Firebase RTDB / WebSocket
    await Future.delayed(const Duration(milliseconds: 500));
    return 'webrtc://$systemId/$cameraId/$streamId';
  }

  /// Send PTZ command to Raspberry Pi 5 -> Camera
  Future<void> sendPtzCommand({
    required String systemId,
    required String cameraId,
    required String command, // UP, DOWN, LEFT, RIGHT, ZOOM_IN, ZOOM_OUT
  }) async {
    // Write PTZ command to RTDB / WebRTC control channel
  }

  /// Request instant high-res snapshot
  Future<String?> requestSnapshot({
    required String systemId,
    required String cameraId,
  }) async {
    return null;
  }
}
