/// Result of enumerating cameras without starting a stream.
///
/// Purpose: capability detection only (Prompt 07) — not a frame source.
final class SieCameraInventory {
  /// Creates an inventory result.
  const SieCameraInventory({
    required this.probed,
    required this.deviceCount,
    required this.hasFrontCamera,
    required this.hasBackCamera,
    this.errorMessage,
  });

  /// Probe was not run (adapter skipped).
  factory SieCameraInventory.notProbed() => const SieCameraInventory(
        probed: false,
        deviceCount: 0,
        hasFrontCamera: false,
        hasBackCamera: false,
      );

  /// Probe completed with zero devices.
  factory SieCameraInventory.empty() => const SieCameraInventory(
        probed: true,
        deviceCount: 0,
        hasFrontCamera: false,
        hasBackCamera: false,
      );

  /// Whether [availableCameras]-style enumeration ran.
  final bool probed;

  /// Number of cameras reported by the platform plugin.
  final int deviceCount;

  /// At least one front-facing camera.
  final bool hasFrontCamera;

  /// At least one back-facing camera.
  final bool hasBackCamera;

  /// Optional error text when enumeration threw (no crash).
  final String? errorMessage;

  /// `true` when at least one device exists.
  bool get hasAnyCamera => probed && deviceCount > 0;
}
