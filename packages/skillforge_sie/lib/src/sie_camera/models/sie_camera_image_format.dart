/// Pixel / buffer format for [SieCameraFrame] planes.
///
/// The Camera Engine does not interpret pixels — formats are labels for
/// downstream vision adapters only.
enum SieCameraImageFormat {
  /// YUV420 (typical Android CameraImage).
  yuv420,

  /// BGRA8888 (typical iOS / some desktop).
  bgra8888,

  /// JPEG-encoded single plane (rare for streams).
  jpeg,

  /// NV21-style or other — treat as opaque.
  unknown,
}
