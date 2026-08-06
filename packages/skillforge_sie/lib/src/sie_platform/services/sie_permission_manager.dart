import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_permission_snapshot.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_permission_port.dart';

/// Manages camera permission lifecycle for SIE (IDS opt-in / denial UX).
///
/// Purpose: check, request, classify permanent denial, expose guidance hooks.
/// Inputs: [CameraPermissionPort].
/// Outputs: [SiePermissionSnapshot]; optional [SieFailure] on hard blocks.
/// Failure behavior: denials are not exceptions; use [ensureGranted] when a
/// caller needs a thrown failure for control flow.
final class SiePermissionManager {
  /// Creates the manager.
  SiePermissionManager({required CameraPermissionPort permissionPort})
      : _port = permissionPort;

  final CameraPermissionPort _port;
  SiePermissionSnapshot _snapshot = SiePermissionSnapshot.unknown();

  /// Last known snapshot (Riverpod-friendly, low frequency).
  SiePermissionSnapshot get snapshot => _snapshot;

  /// Refreshes status without prompting.
  Future<SiePermissionSnapshot> refresh() async {
    final status = await _port.check();
    _snapshot = SiePermissionSnapshot.fromStatus(status);
    return _snapshot;
  }

  /// Requests permission when [SiePermissionSnapshot.canRequest] is true.
  ///
  /// If permanently denied, does not prompt and returns guidance for settings.
  Future<SiePermissionSnapshot> requestCameraPermission() async {
    await refresh();
    if (_snapshot.status.isGranted) return _snapshot;
    if (_snapshot.needsSettings) return _snapshot;
    if (!_snapshot.canRequest) return _snapshot;

    final status = await _port.request();
    _snapshot = SiePermissionSnapshot.fromStatus(status);
    return _snapshot;
  }

  /// Opens OS / site settings when possible.
  Future<bool> openPermissionSettings() => _port.openSettings();

  /// Returns a failure if permission is not granted after refresh/request.
  ///
  /// Inputs: [requestIfNeeded] — when true, attempts a prompt first.
  /// Outputs: `null` if granted; otherwise [SiePermissionDeniedFailure].
  Future<SieFailure?> ensureGranted({bool requestIfNeeded = true}) async {
    await refresh();
    if (_snapshot.status.isGranted) return null;

    if (requestIfNeeded && _snapshot.canRequest) {
      await requestCameraPermission();
      if (_snapshot.status.isGranted) return null;
    }

    if (_snapshot.status == SiePermissionStatus.permanentlyDenied ||
        _snapshot.status == SiePermissionStatus.restricted) {
      return SiePermissionDeniedFailure(
        permanent: true,
        message: _snapshot.guidanceBody,
      );
    }

    if (_snapshot.status == SiePermissionStatus.denied ||
        _snapshot.status == SiePermissionStatus.unknown) {
      return SiePermissionDeniedFailure(
        permanent: false,
        message: _snapshot.guidanceBody,
      );
    }

    return SiePermissionDeniedFailure(
      permanent: _snapshot.needsSettings,
      message: _snapshot.guidanceBody,
    );
  }
}
