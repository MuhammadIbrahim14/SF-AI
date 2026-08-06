/// Configuration for Hand Landmarker backends (MediaPipe-aligned).
final class SieVisionConfig {
  /// Creates config.
  const SieVisionConfig({
    this.numHands = 1,
    this.minHandDetectionConfidence = 0.6,
    this.minHandPresenceConfidence = 0.6,
    this.minTrackingConfidence = 0.5,
    this.lostTimeoutMs = 500,
    this.recoveringTimeoutMs = 120,
  });

  /// SIE v1 defaults (single hand).
  static const SieVisionConfig sieDefaults = SieVisionConfig();

  /// Max hands to return (v1 uses 1; architecture allows >1).
  final int numHands;

  /// MediaPipe min hand detection confidence.
  final double minHandDetectionConfidence;

  /// MediaPipe min hand presence confidence.
  final double minHandPresenceConfidence;

  /// MediaPipe min tracking confidence.
  final double minTrackingConfidence;

  /// After this absence, tracking state → lost.
  final int lostTimeoutMs;

  /// After this absence, tracking state → recovering.
  final int recoveringTimeoutMs;

  /// Copy with overrides.
  SieVisionConfig copyWith({
    int? numHands,
    double? minHandDetectionConfidence,
    double? minHandPresenceConfidence,
    double? minTrackingConfidence,
    int? lostTimeoutMs,
    int? recoveringTimeoutMs,
  }) {
    return SieVisionConfig(
      numHands: numHands ?? this.numHands,
      minHandDetectionConfidence:
          minHandDetectionConfidence ?? this.minHandDetectionConfidence,
      minHandPresenceConfidence:
          minHandPresenceConfidence ?? this.minHandPresenceConfidence,
      minTrackingConfidence:
          minTrackingConfidence ?? this.minTrackingConfidence,
      lostTimeoutMs: lostTimeoutMs ?? this.lostTimeoutMs,
      recoveringTimeoutMs: recoveringTimeoutMs ?? this.recoveringTimeoutMs,
    );
  }
}
