/// Facing / placement of a camera device.
enum SieCameraLensDirection {
  /// User-facing / selfie camera (preferred for SIE).
  front,

  /// World-facing camera.
  back,

  /// External / USB / unknown placement.
  external,
}

/// Extension helpers.
extension SieCameraLensDirectionX on SieCameraLensDirection {
  /// Stable config / log label.
  String get label => name;
}
