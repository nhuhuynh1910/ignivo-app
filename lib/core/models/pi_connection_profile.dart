import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fireguard_api_service.dart';

class PiConnectionProfile {
  const PiConnectionProfile({
    required this.systemName,
    required this.piHost,
    required this.eyeUrl,
    required this.guardUrl,
    this.isCustomAdvanced = false,
    this.version = 2,
  });

  static const defaultSystemName = 'Hệ thống IGNIVO Pi';
  static const defaultPiHost = '100.95.189.60';
  static const defaultEyeUrl = 'http://100.95.189.60:8000';
  static const defaultGuardUrl = 'http://100.95.189.60:8080';

  static const prefProfileKey = 'ignivo_pi_connection_profile';
  static const prefLegacyGuardKey = 'fireguard_edge_base_url';

  final String systemName;
  final String piHost;
  final String eyeUrl;
  final String guardUrl;
  final bool isCustomAdvanced;
  final int version;

  static PiConnectionProfile createDefault() => const PiConnectionProfile(
    systemName: defaultSystemName,
    piHost: defaultPiHost,
    eyeUrl: defaultEyeUrl,
    guardUrl: defaultGuardUrl,
    isCustomAdvanced: false,
    version: 2,
  );

  static PiConnectionProfile fromHost(
    String hostInput, {
    String? systemName,
    String defaultScheme = 'http',
  }) {
    var input = hostInput.trim();
    if (input.isEmpty) {
      return createDefault();
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
      host = defaultPiHost;
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
      isCustomAdvanced: false,
      version: 2,
    );
  }

  static PiConnectionProfile fromCustomUrls({
    required String systemName,
    required String eyeUrl,
    required String guardUrl,
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
      piHost: eyeUri.host,
      eyeUrl: normEye,
      guardUrl: normGuard,
      isCustomAdvanced: !isStandard,
      version: 2,
    );
  }

  Map<String, dynamic> toJson() => {
    'systemName': systemName,
    'piHost': piHost,
    'eyeUrl': eyeUrl,
    'guardUrl': guardUrl,
    'isCustomAdvanced': isCustomAdvanced,
    'version': version,
  };

  factory PiConnectionProfile.fromJson(Map<String, dynamic> json) =>
      PiConnectionProfile(
        systemName: json['systemName']?.toString() ?? defaultSystemName,
        piHost: json['piHost']?.toString() ?? defaultPiHost,
        eyeUrl: json['eyeUrl']?.toString() ?? defaultEyeUrl,
        guardUrl: json['guardUrl']?.toString() ?? defaultGuardUrl,
        isCustomAdvanced: json['isCustomAdvanced'] == true,
        version: json['version'] as int? ?? 2,
      );

  static Future<PiConnectionProfile> load(SharedPreferences prefs) async {
    final rawJson = prefs.getString(prefProfileKey);
    if (rawJson != null) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          return PiConnectionProfile.fromJson(decoded);
        }
      } catch (_) {}
    }

    // Migration from legacy single URL or base URL
    final legacyGuard = prefs.getString(prefLegacyGuardKey);
    if (legacyGuard != null) {
      try {
        final normGuard = FireguardApiService.normalizeBaseUrl(legacyGuard);
        final guardUri = Uri.parse(normGuard);
        if (guardUri.port == 8080) {
          final normEye = guardUri.replace(port: 8000).toString();
          return PiConnectionProfile(
            systemName: defaultSystemName,
            piHost: guardUri.host,
            eyeUrl: normEye,
            guardUrl: normGuard,
            isCustomAdvanced: false,
            version: 2,
          );
        } else {
          // Custom port
          final normEye = guardUri.replace(port: 8000).toString();
          return PiConnectionProfile(
            systemName: defaultSystemName,
            piHost: guardUri.host,
            eyeUrl: normEye,
            guardUrl: normGuard,
            isCustomAdvanced: true,
            version: 2,
          );
        }
      } catch (_) {}
    }

    return createDefault();
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(prefProfileKey, jsonEncode(toJson()));
    // Keep legacy key synced for background services
    await prefs.setString(prefLegacyGuardKey, guardUrl);
  }
}
