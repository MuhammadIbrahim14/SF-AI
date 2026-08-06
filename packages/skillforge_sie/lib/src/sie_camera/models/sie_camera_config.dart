import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lens_direction.dart';

/// Preferred resolution band for SIE capture (maps to plugin presets).
enum SieCameraResolutionPreset {
  /// ~352x288
  low,

  /// ~640x480 — default for vision balance.
  medium,

  /// ~1280x720
  high,

  /// Highest available (use sparingly).
  max,
}

/// Camera selection preference.
enum SieCameraSelectionPreference {
  /// Prefer front / user-facing (SIE default).
  front,

  /// Prefer back / world-facing.
  back,

  /// Prefer external when present.
  external,

  /// First available device.
  any,
}

/// Immutable capture configuration for the Camera Engine.
///
/// Purpose: configure stream without embedding vision thresholds.
final class SieCameraConfig {
  /// Creates config.
  const SieCameraConfig({
    this.selection = SieCameraSelectionPreference.front,
    this.preferredDeviceId,
    this.resolution = SieCameraResolutionPreset.medium,
    this.targetFps = 30,
    this.enableAudio = false,
    this.maxQueuedFrames = 1,
  });

  /// Default SIE capture profile.
  static const SieCameraConfig sieDefaults = SieCameraConfig();

  /// Lens preference when [preferredDeviceId] is null.
  final SieCameraSelectionPreference selection;

  /// Explicit device id override (wins over [selection] when found).
  final String? preferredDeviceId;

  /// Resolution band.
  final SieCameraResolutionPreset resolution;

  /// Target FPS hint (best-effort; platform may clamp).
  final int targetFps;

  /// Audio must stay off for SIE privacy.
  final bool enableAudio;

  /// Back-pressure: keep at most this many unconsumed frames (extras dropped).
  final int maxQueuedFrames;

  /// Copy with overrides.
  SieCameraConfig copyWith({
    SieCameraSelectionPreference? selection,
    String? preferredDeviceId,
    bool clearPreferredDeviceId = false,
    SieCameraResolutionPreset? resolution,
    int? targetFps,
    bool? enableAudio,
    int? maxQueuedFrames,
  }) {
    return SieCameraConfig(
      selection: selection ?? this.selection,
      preferredDeviceId: clearPreferredDeviceId
          ? null
          : (preferredDeviceId ?? this.preferredDeviceId),
      resolution: resolution ?? this.resolution,
      targetFps: targetFps ?? this.targetFps,
      enableAudio: enableAudio ?? this.enableAudio,
      maxQueuedFrames: maxQueuedFrames ?? this.maxQueuedFrames,
    );
  }

  /// Maps selection preference to lens direction (null = any).
  SieCameraLensDirection? get preferredLens => switch (selection) {
        SieCameraSelectionPreference.front => SieCameraLensDirection.front,
        SieCameraSelectionPreference.back => SieCameraLensDirection.back,
        SieCameraSelectionPreference.external => SieCameraLensDirection.external,
        SieCameraSelectionPreference.any => null,
      };
}
