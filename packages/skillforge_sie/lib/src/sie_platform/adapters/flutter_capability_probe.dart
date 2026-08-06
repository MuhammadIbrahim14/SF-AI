import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_platform/ports/capability_probe_port.dart';

import 'secure_context_stub.dart'
    if (dart.library.html) 'secure_context_web.dart' as secure_context;
import 'media_devices_stub.dart'
    if (dart.library.html) 'media_devices_web.dart' as media_devices;

/// Flutter / browser environment probe (no camera stream).
final class FlutterCapabilityProbe implements CapabilityProbePort {
  /// Creates the probe.
  const FlutterCapabilityProbe();

  @override
  Future<EnvironmentCapabilityFacts> probe() async {
    if (kIsWeb) {
      final secure = secure_context.isSecureContext();
      final media = media_devices.hasMediaDevices();
      return EnvironmentCapabilityFacts(
        secureContext: secure,
        mediaDevicesApiAvailable: media,
        cameraPermissionApiAvailable: secure && media,
      );
    }

    // Native: permission_handler + camera plugin cover API surface.
    return const EnvironmentCapabilityFacts(
      secureContext: true,
      mediaDevicesApiAvailable: true,
      cameraPermissionApiAvailable: true,
    );
  }
}
