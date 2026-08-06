import 'package:skillforge_sie/src/sie_core/platform_kind.dart';

/// Immutable performance / limitation profile for a [SiePlatformKind].
///
/// Purpose: describe supported features and recommended defaults without
/// performing I/O (Document 06 matrix).
/// Inputs: [SiePlatformKind].
/// Outputs: static expectations for higher layers.
/// Failure behavior: unknown platforms map via [forKind] to a disabled profile.
final class SiePlatformProfile {
  /// Creates a profile.
  const SiePlatformProfile({
    required this.platform,
    required this.sieSupported,
    required this.cameraApiSupported,
    required this.continuousFrameStreamingSupported,
    required this.handTrackingExpected,
    required this.targetCameraFps,
    required this.targetVisionFps,
    required this.limitations,
    required this.notes,
  });

  /// Platform this profile describes.
  final SiePlatformKind platform;

  /// Whether SIE may be offered at all on this platform (v1 policy).
  final bool sieSupported;

  /// Whether a camera permission / capture API exists in principle.
  final bool cameraApiSupported;

  /// Whether continuous frame streaming is considered production-ready.
  final bool continuousFrameStreamingSupported;

  /// Whether a MediaPipe-class hand tracker is expected to be wirable.
  final bool handTrackingExpected;

  /// Recommended camera clock (FPS).
  final int targetCameraFps;

  /// Recommended vision clock (FPS).
  final int targetVisionFps;

  /// Short limitation strings for diagnostics / host copy.
  final List<String> limitations;

  /// Engineer-facing notes.
  final String notes;

  /// Returns the frozen v1 profile for [kind].
  factory SiePlatformProfile.forKind(SiePlatformKind kind) {
    return switch (kind) {
      SiePlatformKind.web => const SiePlatformProfile(
          platform: SiePlatformKind.web,
          sieSupported: true,
          cameraApiSupported: true,
          continuousFrameStreamingSupported: true,
          handTrackingExpected: true,
          targetCameraFps: 30,
          targetVisionFps: 20,
          limitations: [
            'Requires secure context (HTTPS or localhost).',
            'Tab hidden → session must pause (no background camera).',
            'Safari / older browsers may lack APIs.',
          ],
          notes: 'P0 launch target. MediaPipe Tasks Vision via JS adapter.',
        ),
      SiePlatformKind.android => const SiePlatformProfile(
          platform: SiePlatformKind.android,
          sieSupported: true,
          cameraApiSupported: true,
          continuousFrameStreamingSupported: true,
          handTrackingExpected: true,
          targetCameraFps: 30,
          targetVisionFps: 20,
          limitations: [
            'Runtime CAMERA permission required.',
            'Thermal / battery pressure on long sessions.',
            'OEM camera quirks possible.',
          ],
          notes: 'P0 launch target. Native MediaPipe / TFLite adapter.',
        ),
      SiePlatformKind.windows => const SiePlatformProfile(
          platform: SiePlatformKind.windows,
          sieSupported: false,
          cameraApiSupported: true,
          continuousFrameStreamingSupported: false,
          handTrackingExpected: false,
          targetCameraFps: 0,
          targetVisionFps: 0,
          limitations: [
            'Continuous camera frame streaming not production-ready via standard plugins.',
            'SIE v1 de-scoped for Windows until a proven frame source exists.',
          ],
          notes: 'Detected for messaging only; fail-soft unsupported for SIE session.',
        ),
      SiePlatformKind.macos => const SiePlatformProfile(
          platform: SiePlatformKind.macos,
          sieSupported: false,
          cameraApiSupported: true,
          continuousFrameStreamingSupported: false,
          handTrackingExpected: false,
          targetCameraFps: 0,
          targetVisionFps: 0,
          limitations: [
            'Desktop SIE is a future milestone.',
            'TCC camera entitlements required when enabled.',
          ],
          notes: 'Secondary desktop — not a v1 launch target.',
        ),
      SiePlatformKind.linux => const SiePlatformProfile(
          platform: SiePlatformKind.linux,
          sieSupported: false,
          cameraApiSupported: true,
          continuousFrameStreamingSupported: false,
          handTrackingExpected: false,
          targetCameraFps: 0,
          targetVisionFps: 0,
          limitations: [
            'Driver and portal variance across distros.',
            'Not a v1 launch target.',
          ],
          notes: 'Best-effort future; fail-soft today.',
        ),
      SiePlatformKind.ios => const SiePlatformProfile(
          platform: SiePlatformKind.ios,
          sieSupported: false,
          cameraApiSupported: true,
          continuousFrameStreamingSupported: false,
          handTrackingExpected: false,
          targetCameraFps: 0,
          targetVisionFps: 0,
          limitations: [
            'iOS / iPadOS SIE is a future SKU.',
          ],
          notes: 'Detected for fail-soft messaging only in v1.',
        ),
      SiePlatformKind.unsupported => const SiePlatformProfile(
          platform: SiePlatformKind.unsupported,
          sieSupported: false,
          cameraApiSupported: false,
          continuousFrameStreamingSupported: false,
          handTrackingExpected: false,
          targetCameraFps: 0,
          targetVisionFps: 0,
          limitations: ['Platform is not recognized for SIE.'],
          notes: 'Fail gracefully; traditional input only.',
        ),
    };
  }
}
