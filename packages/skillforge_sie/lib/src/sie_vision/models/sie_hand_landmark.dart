/// One MediaPipe-style hand landmark (normalized image coordinates).
///
/// Purpose: platform-independent landmark atom for Landmark Engine.
/// Semantics stay close to MediaPipe Hand Landmarker (x,y in 0–1, z relative).
final class SieHandLandmark {
  /// Creates a landmark.
  const SieHandLandmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
    this.presence,
  });

  /// Normalized X (typically 0–1).
  final double x;

  /// Normalized Y (typically 0–1).
  final double y;

  /// Relative depth (MediaPipe semantic; not meters).
  final double z;

  /// Optional visibility score when provided by the backend.
  final double? visibility;

  /// Optional presence score when provided by the backend.
  final double? presence;
}
