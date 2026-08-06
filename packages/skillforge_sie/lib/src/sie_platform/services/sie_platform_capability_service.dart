import 'package:skillforge_sie/src/sie_config/sie_config_snapshot.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_flags.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_id.dart';
import 'package:skillforge_sie/src/sie_config/sie_platform_profile.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_camera_inventory.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_platform_capabilities.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_unsupported_reason.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_inventory_port.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_permission_port.dart';
import 'package:skillforge_sie/src/sie_platform/ports/capability_probe_port.dart';
import 'package:skillforge_sie/src/sie_platform/ports/platform_detector_port.dart';

/// Orchestrates platform detection + capability probing for SIE.
///
/// Purpose: single entry point for “can SIE run here?” without vision/gestures.
/// Inputs: injected ports + optional [SieFeatureFlags] / config.
/// Outputs: [SiePlatformCapabilities] and [SieConfigSnapshot].
/// Failure behavior: never throws for unsupported platforms — encodes reasons.
final class SiePlatformCapabilityService {
  /// Creates the service.
  SiePlatformCapabilityService({
    required PlatformDetectorPort detector,
    required CapabilityProbePort capabilityProbe,
    required CameraPermissionPort permissionPort,
    required CameraInventoryPort cameraInventory,
    SieFeatureFlags? featureFlags,
    bool developerMode = false,
  })  : _detector = detector,
        _capabilityProbe = capabilityProbe,
        _permissionPort = permissionPort,
        _cameraInventory = cameraInventory,
        _featureFlags = featureFlags ?? SieFeatureFlags.defaults(),
        _developerMode = developerMode;

  final PlatformDetectorPort _detector;
  final CapabilityProbePort _capabilityProbe;
  final CameraPermissionPort _permissionPort;
  final CameraInventoryPort _cameraInventory;
  SieFeatureFlags _featureFlags;
  bool _developerMode;

  /// Current feature flags (mutable only via [updateFeatureFlags]).
  SieFeatureFlags get featureFlags => _featureFlags;

  /// Builds config snapshot for the detected platform.
  SieConfigSnapshot currentConfig({SiePlatformKind? platform}) {
    final kind = platform ?? _detector.detect();
    return SieConfigSnapshot.forPlatform(
      kind,
      featureFlags: _featureFlags,
      developerMode: _developerMode,
    );
  }

  /// Replaces feature flags without touching engine internals.
  void updateFeatureFlags(SieFeatureFlags flags) {
    _featureFlags = flags;
  }

  /// Updates developer mode bit on subsequent snapshots.
  // ignore: avoid_positional_boolean_parameters
  void setDeveloperMode(bool enabled) {
    _developerMode = enabled;
  }

  /// Detects platform only (sync, no I/O).
  SiePlatformKind detectPlatform() => _detector.detect();

  /// Full capability probe.
  ///
  /// When [enumerateCameras] is false, skips device enumeration (useful when
  /// permission is not granted yet).
  Future<SiePlatformCapabilities> probe({
    bool enumerateCameras = true,
    bool refreshPermission = true,
  }) async {
    final platform = _detector.detect();
    final profile = SiePlatformProfile.forKind(platform);
    final env = await _capabilityProbe.probe();

    var permission = SiePermissionStatus.unknown;
    if (refreshPermission) {
      permission = await _permissionPort.check();
    }

    var inventory = SieCameraInventory.notProbed();
    if (enumerateCameras &&
        profile.cameraApiSupported &&
        env.cameraPermissionApiAvailable &&
        env.secureContext) {
      inventory = await _cameraInventory.probe();
    }

    return evaluate(
      platform: platform,
      profile: profile,
      env: env,
      permission: permission,
      inventory: inventory,
      flags: _featureFlags,
    );
  }

  /// Pure evaluation used by [probe] and unit tests.
  static SiePlatformCapabilities evaluate({
    required SiePlatformKind platform,
    required SiePlatformProfile profile,
    required EnvironmentCapabilityFacts env,
    required SiePermissionStatus permission,
    required SieCameraInventory inventory,
    required SieFeatureFlags flags,
    DateTime? probedAt,
  }) {
    SieUnsupportedReason? reason;
    String? guidance;
    var runnable = true;

    if (!profile.sieSupported) {
      runnable = false;
      reason = profile.continuousFrameStreamingSupported
          ? SieUnsupportedReason.platformNotSupported
          : SieUnsupportedReason.continuousStreamingUnavailable;
      if (platform == SiePlatformKind.windows) {
        reason = SieUnsupportedReason.continuousStreamingUnavailable;
      } else if (platform == SiePlatformKind.unsupported) {
        reason = SieUnsupportedReason.platformNotSupported;
      } else {
        reason = SieUnsupportedReason.platformNotSupported;
      }
      guidance =
          'Spatial Interaction is not available on ${platform.displayName} in this version. '
          'Continue with mouse or touch.';
    } else if (!flags.isEnabled(SieFeatureId.camera)) {
      runnable = false;
      reason = SieUnsupportedReason.featureDisabled;
      guidance = 'Camera feature flag is disabled for SIE.';
    } else if (!env.secureContext) {
      runnable = false;
      reason = SieUnsupportedReason.browserLimitation;
      guidance =
          'Camera requires a secure context (HTTPS or localhost). Open SkillForge over HTTPS.';
    } else if (!env.mediaDevicesApiAvailable || !env.cameraPermissionApiAvailable) {
      runnable = false;
      reason = SieUnsupportedReason.browserLimitation;
      guidance =
          'This browser is missing required camera APIs. Try Chrome or Edge, or use mouse/touch.';
    } else if (!profile.cameraApiSupported) {
      runnable = false;
      reason = SieUnsupportedReason.cameraApiUnavailable;
      guidance = 'No camera API is available on this platform.';
    } else if (!profile.continuousFrameStreamingSupported) {
      runnable = false;
      reason = SieUnsupportedReason.continuousStreamingUnavailable;
      guidance =
          'Continuous camera streaming is not supported for SIE on this platform yet.';
    } else if (permission == SiePermissionStatus.permanentlyDenied ||
        permission == SiePermissionStatus.restricted) {
      runnable = false;
      reason = SieUnsupportedReason.permissionBlocked;
      guidance =
          'Camera permission is blocked. Open settings to enable it, or continue without SIE.';
    } else if (inventory.probed && !inventory.hasAnyCamera) {
      runnable = false;
      reason = SieUnsupportedReason.noCameraDevice;
      guidance =
          'No camera was detected. Connect a camera or continue with mouse/touch.';
    }

    // Permission denied (soft) still allows "runnable" probe so host can show
    // request UX; session start will re-check. Mark runnable true but note via
    // permission status — only permanent blocks above.
    if (runnable && !flags.isEnabled(SieFeatureId.handTracking)) {
      // Camera-only capability layer remains runnable; later modules gate.
    }

    return SiePlatformCapabilities(
      platform: platform,
      profile: profile,
      cameraApiAvailable:
          profile.cameraApiSupported && env.cameraPermissionApiAvailable,
      continuousStreamingAvailable:
          profile.continuousFrameStreamingSupported && env.secureContext,
      permissionStatus: permission,
      cameraInventory: inventory,
      secureContext: env.secureContext,
      mediaDevicesApiAvailable: env.mediaDevicesApiAvailable,
      sieRunnable: runnable,
      unsupportedReason: reason,
      guidanceMessage: guidance,
      probedAt: probedAt ?? DateTime.now(),
    );
  }
}
