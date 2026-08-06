/// One validated, normalized landmark (immutable).
///
/// Platform-independent; no MediaPipe types.
final class SieNormalizedLandmark {
  /// Creates a normalized landmark.
  const SieNormalizedLandmark({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
    this.presence,
  });

  /// Landmark index in MediaPipe hand topology (0–20).
  final int index;

  /// Normalized X in a stable domain (typically [0,1] after clamp).
  final double x;

  /// Normalized Y.
  final double y;

  /// Relative depth (unchanged semantics from vision).
  final double z;

  /// Preserved visibility if present.
  final double? visibility;

  /// Preserved presence if present.
  final double? presence;
}
