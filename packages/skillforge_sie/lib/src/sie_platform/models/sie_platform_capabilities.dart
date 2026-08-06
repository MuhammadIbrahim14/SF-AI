import 'package:skillforge_sie/src/sie_config/sie_platform_profile.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_camera_inventory.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_unsupported_reason.dart';

/// Immutable capability report for the current runtime.
///
/// Purpose: tell session/host whether SIE may start (no vision/gestures here).
/// Inputs: detector + probes + permission snapshot + inventory.
/// Outputs: booleans + optional [unsupportedReason].
/// Failure behavior: always constructible; degradations encoded as fields.
final class SiePlatformCapabilities {
  /// Creates a capability snapshot.
  const SiePlatformCapabilities({
    required this.platform,
    required this.profile,
    required this.cameraApiAvailable,
    required this.continuousStreamingAvailable,
    required this.permissionStatus,
    required this.cameraInventory,
    required this.secureContext,
    required this.mediaDevicesApiAvailable,
    required this.sieRunnable,
    this.unsupportedReason,
    this.guidanceMessage,
    this.probedAt,
  });

  /// Detected platform.
  final SiePlatformKind platform;

  /// Static profile for [platform].
  final SiePlatformProfile profile;

  /// Camera permission / capture API appears present.
  final bool cameraApiAvailable;

  /// Continuous frames considered available for SIE on this runtime.
  final bool continuousStreamingAvailable;

  /// Last known permission status (may be [SiePermissionStatus.unknown]).
  final SiePermissionStatus permissionStatus;

  /// Device enumeration result.
  final SieCameraInventory cameraInventory;

  /// Web secure context (non-web → `true`).
  final bool secureContext;

  /// `navigator.mediaDevices` style API present (non-web → `true` when camera API ok).
  final bool mediaDevicesApiAvailable;

  /// Aggregate: SIE session is allowed to proceed to later layers.
  final bool sieRunnable;

  /// Primary block reason when [sieRunnable] is false.
  final SieUnsupportedReason? unsupportedReason;

  /// Host-facing guidance (permission / settings / HTTPS).
  final String? guidanceMessage;

  /// Wall-clock probe time when available.
  final DateTime? probedAt;

  /// Copy with permission / inventory updates after a refresh.
  SiePlatformCapabilities copyWith({
    SiePermissionStatus? permissionStatus,
    SieCameraInventory? cameraInventory,
    bool? sieRunnable,
    SieUnsupportedReason? unsupportedReason,
    String? guidanceMessage,
    DateTime? probedAt,
    bool clearUnsupportedReason = false,
  }) {
    return SiePlatformCapabilities(
      platform: platform,
      profile: profile,
      cameraApiAvailable: cameraApiAvailable,
      continuousStreamingAvailable: continuousStreamingAvailable,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      cameraInventory: cameraInventory ?? this.cameraInventory,
      secureContext: secureContext,
      mediaDevicesApiAvailable: mediaDevicesApiAvailable,
      sieRunnable: sieRunnable ?? this.sieRunnable,
      unsupportedReason: clearUnsupportedReason
          ? null
          : (unsupportedReason ?? this.unsupportedReason),
      guidanceMessage: guidanceMessage ?? this.guidanceMessage,
      probedAt: probedAt ?? this.probedAt,
    );
  }
}
