import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fireguard_api_service.dart';

class PiConnectionProfile {
  const PiConnectionProfile({
    required this.systemName,
    required this.piHost,
    required this.eyeUrl,
    required this.guardUrl,
    this.isConfigured = false,
    this.deviceId,
    this.isCustomAdvanced = false,
    this.version = 3,
  });

  static const defaultSystemName = 'Hệ thống IGNIVO';
  static const defaultPiHost = '100.95.189.60';
  static const defaultEyeUrl = 'http://100.95.189.60:8000';
  static const defaultGuardUrl = 'http://100.95.189.60:8080';

  static const prefProfileKey = 'ignivo_pi_connection_profile';
  static const prefLegacyGuardKey = 'fireguard_edge_base_url';

  final String systemName;
  final String piHost;
  final String eyeUrl;
  final String guardUrl;
  final bool isConfigured;
  final String? deviceId;
  final bool isCustomAdvanced;
  final int version;

  static PiConnectionProfile createUnconfigured() => const PiConnectionProfile(
    systemName: defaultSystemName,
    piHost: '',
    eyeUrl: '',
    guardUrl: '',
    isConfigured: false,
    deviceId: null,
    isCustomAdvanced: false,
    version: 3,
  );

  static PiConnectionProfile createDefault() => const PiConnectionProfile(
    systemName: defaultSystemName,
    piHost: defaultPiHost,
    eyeUrl: defaultEyeUrl,
    guardUrl: defaultGuardUrl,
    isConfigured: true,
    deviceId: null,
    isCustomAdvanced: false,
    version: 3,
  );

  static PiConnectionProfile fromHost(
    String hostInput, {
    String? systemName,
    String defaultScheme = 'http',
  }) {
    var input = hostInput.trim();
    if (input.isEmpty) {
      return createUnconfigured();
    }
    String scheme = defaultScheme;
    if (input.contains('://')) {
      final parts = input.split('://');
      scheme = parts[0].toLowerCase();
      input = parts.sublist(1).join('://');
    }
    // Remove trailing slashes and paths
    final slashIndex = input.indexOf('/');
    if (slashIndex != -1) {
      input = input.substring(0, slashIndex);
    }
    // Remove port if user typed one in single host mode
    String host = input;
    if (host.startsWith('[')) {
      // IPv6 literal
      final endBracket = host.indexOf(']');
      if (endBracket != -1) {
        host = host.substring(0, endBracket + 1);
      }
    } else {
      final colonIndex = host.lastIndexOf(':');
      if (colonIndex != -1) {
        host = host.substring(0, colonIndex);
      }
    }
    if (host.isEmpty) {
      return createUnconfigured();
    }

    final eye = Uri(scheme: scheme, host: host, port: 8000).toString();
    final guard = Uri(scheme: scheme, host: host, port: 8080).toString();

    return PiConnectionProfile(
      systemName: (systemName?.trim().isNotEmpty ?? false)
          ? systemName!.trim()
          : defaultSystemName,
      piHost: host,
      eyeUrl: eye,
      guardUrl: guard,
      isConfigured: true,
      deviceId: null,
      isCustomAdvanced: false,
      version: 3,
    );
  }

  static PiConnectionProfile fromGuardUrl(
    String urlInput, {
    String? systemName,
    String? deviceId,
  }) {
    final normGuard = FireguardApiService.normalizeBaseUrl(urlInput);
    final guardUri = Uri.parse(normGuard);
    final scheme = guardUri.scheme;
    final host = guardUri.host;
    final eyePort = guardUri.port == 8080 ? 8000 : (guardUri.hasPort ? guardUri.port : 8000);
    final eye = Uri(scheme: scheme, host: host, port: eyePort).toString();

    final isStandard =
        guardUri.port == 8080 &&
        (scheme == 'http' || scheme == 'https');

    return PiConnectionProfile(
      systemName: (systemName?.trim().isNotEmpty ?? false)
          ? systemName!.trim()
          : defaultSystemName,
      piHost: host,
      eyeUrl: eye,
      guardUrl: normGuard,
      isConfigured: true,
      deviceId: deviceId,
      isCustomAdvanced: !isStandard,
      version: 3,
    );
  }

  static PiConnectionProfile fromCustomUrls({
    required String systemName,
    required String eyeUrl,
    required String guardUrl,
    String? deviceId,
  }) {
    final normEye = FireguardApiService.normalizeBaseUrl(eyeUrl);
    final normGuard = FireguardApiService.normalizeBaseUrl(guardUrl);

    final eyeUri = Uri.parse(normEye);
    final guardUri = Uri.parse(normGuard);

    final isStandard =
        eyeUri.host == guardUri.host &&
        eyeUri.scheme == guardUri.scheme &&
        eyeUri.port == 8000 &&
        guardUri.port == 8080;

    return PiConnectionProfile(
      systemName: systemName.trim().isNotEmpty
          ? systemName.trim()
          : defaultSystemName,
      piHost: guardUri.host.isNotEmpty ? guardUri.host : eyeUri.host,
      eyeUrl: normEye,
      guardUrl: normGuard,
      isConfigured: normGuard.isNotEmpty,
      deviceId: deviceId,
      isCustomAdvanced: !isStandard,
      version: 3,
    );
  }

  PiConnectionProfile copyWith({
    String? systemName,
    String? piHost,
    String? eyeUrl,
    String? guardUrl,
    bool? isConfigured,
    String? deviceId,
    bool? isCustomAdvanced,
    int? version,
  }) => PiConnectionProfile(
    systemName: systemName ?? this.systemName,
    piHost: piHost ?? this.piHost,
    eyeUrl: eyeUrl ?? this.eyeUrl,
    guardUrl: guardUrl ?? this.guardUrl,
    isConfigured: isConfigured ?? this.isConfigured,
    deviceId: deviceId ?? this.deviceId,
    isCustomAdvanced: isCustomAdvanced ?? this.isCustomAdvanced,
    version: version ?? this.version,
  );

  Map<String, dynamic> toJson() => {
    'systemName': systemName,
    'piHost': piHost,
    'eyeUrl': eyeUrl,
    'guardUrl': guardUrl,
    'isConfigured': isConfigured,
    'deviceId': deviceId,
    'isCustomAdvanced': isCustomAdvanced,
    'version': version,
  };

  factory PiConnectionProfile.fromJson(Map<String, dynamic> json) {
    final guardUrl = json['guardUrl']?.toString() ?? '';
    final hasGuard = guardUrl.trim().isNotEmpty;
    final isConfigured = json.containsKey('isConfigured')
        ? json['isConfigured'] == true
        : hasGuard;

    return PiConnectionProfile(
      systemName: json['systemName']?.toString() ?? defaultSystemName,
      piHost: json['piHost']?.toString() ?? defaultPiHost,
      eyeUrl: json['eyeUrl']?.toString() ?? defaultEyeUrl,
      guardUrl: guardUrl.isNotEmpty ? guardUrl : defaultGuardUrl,
      isConfigured: isConfigured,
      deviceId: json['deviceId']?.toString(),
      isCustomAdvanced: json['isCustomAdvanced'] == true,
      version: json['version'] as int? ?? 3,
    );
  }

  static Future<PiConnectionProfile> load(SharedPreferences prefs) async {
    final rawJson = prefs.getString(prefProfileKey);
    if (rawJson != null) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          return PiConnectionProfile.fromJson(decoded);
        }
      } catch (_) {
        // Corrupt configuration requires setup, do not silently fallback to mock IP
        return createUnconfigured();
      }
    }

    // Migration from legacy single URL or base URL
    final legacyGuard = prefs.getString(prefLegacyGuardKey);
    if (legacyGuard != null && legacyGuard.trim().isNotEmpty) {
      try {
        return fromGuardUrl(legacyGuard, systemName: defaultSystemName);
      } catch (_) {}
    }

    // Fresh install: unconfigured
    return createUnconfigured();
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(prefProfileKey, jsonEncode(toJson()));
    if (guardUrl.isNotEmpty) {
      await prefs.setString(prefLegacyGuardKey, guardUrl);
    }
  }
}
