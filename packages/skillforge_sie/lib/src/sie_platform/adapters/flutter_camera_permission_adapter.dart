import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_permission_port.dart';

/// Maps `permission_handler` to [CameraPermissionPort].
///
/// On Web, `permission_handler` support is limited; check/request still attempt
/// best-effort mapping. Secure-context gating is handled by the capability
/// service before requests.
final class FlutterCameraPermissionAdapter implements CameraPermissionPort {
  /// Creates the adapter.
  const FlutterCameraPermissionAdapter();

  @override
  Future<SiePermissionStatus> check() async {
    try {
      if (kIsWeb) {
        // Browser does not always expose a stable pre-prompt status.
        return SiePermissionStatus.unknown;
      }
      final status = await ph.Permission.camera.status;
      return _map(status);
    } catch (_) {
      return SiePermissionStatus.error;
    }
  }

  @override
  Future<SiePermissionStatus> request() async {
    try {
      if (kIsWeb) {
        // Actual getUserMedia prompt belongs to the future camera engine.
        // Capability layer records intent to request; treat as unknown→denied
        // without streaming. Hosts should not assume granted on web until
        // camera engine confirms.
        return SiePermissionStatus.unknown;
      }
      final status = await ph.Permission.camera.request();
      return _map(status);
    } catch (_) {
      return SiePermissionStatus.error;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  static SiePermissionStatus _map(ph.PermissionStatus status) {
    return switch (status) {
      ph.PermissionStatus.denied => SiePermissionStatus.denied,
      ph.PermissionStatus.granted => SiePermissionStatus.granted,
      ph.PermissionStatus.restricted => SiePermissionStatus.restricted,
      ph.PermissionStatus.limited => SiePermissionStatus.granted,
      ph.PermissionStatus.permanentlyDenied =>
        SiePermissionStatus.permanentlyDenied,
      ph.PermissionStatus.provisional => SiePermissionStatus.granted,
    };
  }
}
