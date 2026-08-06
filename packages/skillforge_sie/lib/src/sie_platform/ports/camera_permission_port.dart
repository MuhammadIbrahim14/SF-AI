import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';

/// Camera permission port (IDS explicit opt-in).
///
/// Purpose: request/check camera permission without UI widgets.
/// Inputs: none (OS dialogs may appear on [request]).
/// Outputs: [SiePermissionStatus].
/// Failure behavior: map errors to [SiePermissionStatus.error]; do not throw
/// for normal denial paths.
abstract interface class CameraPermissionPort {
  /// Reads current permission without necessarily prompting.
  Future<SiePermissionStatus> check();

  /// Requests permission (may show a system/browser prompt).
  Future<SiePermissionStatus> request();

  /// Opens application / site settings when supported.
  ///
  /// Returns `false` when the platform cannot deep-link to settings.
  Future<bool> openSettings();
}
