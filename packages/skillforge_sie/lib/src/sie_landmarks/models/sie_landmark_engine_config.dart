/// Configuration for the Landmark Engine (validation + stabilization).
final class SieLandmarkEngineConfig {
  /// Creates config.
  const SieLandmarkEngineConfig({
    this.expectedLandmarkCount = 21,
    this.minLandmarkCount = 21,
    this.coordinateMin = -0.5,
    this.coordinateMax = 1.5,
    this.clampToUnitSquare = true,
    this.stabilizationAlpha = 0.4,
    this.enableStabilization = true,
    this.rejectCollapsedHands = true,
    this.collapsedEpsilon = 1e-6,
  });

  /// SIE v1 defaults (MediaPipe Hand Landmarker = 21 points).
  static const SieLandmarkEngineConfig sieDefaults = SieLandmarkEngineConfig();

  /// Exact expected count for a full hand (MediaPipe).
  final int expectedLandmarkCount;

  /// Minimum accepted count (usually same as expected for v1).
  final int minLandmarkCount;

  /// Soft range before rejection (MediaPipe ~0–1; allow mild overshoot).
  final double coordinateMin;

  /// Soft range max before rejection.
  final double coordinateMax;

  /// When true, clamp x/y into [0,1] after validation (platform-independent).
  final bool clampToUnitSquare;

  /// EMA alpha for temporal stabilization (higher = more responsive).
  final double stabilizationAlpha;

  /// When false, pass normalized landmarks without EMA.
  final bool enableStabilization;

  /// Reject hands where all landmarks are essentially identical.
  final bool rejectCollapsedHands;

  /// Epsilon for collapsed-structure detection.
  final double collapsedEpsilon;

  /// Copy with overrides.
  SieLandmarkEngineConfig copyWith({
    int? expectedLandmarkCount,
    int? minLandmarkCount,
    double? coordinateMin,
    double? coordinateMax,
    bool? clampToUnitSquare,
    double? stabilizationAlpha,
    bool? enableStabilization,
    bool? rejectCollapsedHands,
    double? collapsedEpsilon,
  }) {
    return SieLandmarkEngineConfig(
      expectedLandmarkCount:
          expectedLandmarkCount ?? this.expectedLandmarkCount,
      minLandmarkCount: minLandmarkCount ?? this.minLandmarkCount,
      coordinateMin: coordinateMin ?? this.coordinateMin,
      coordinateMax: coordinateMax ?? this.coordinateMax,
      clampToUnitSquare: clampToUnitSquare ?? this.clampToUnitSquare,
      stabilizationAlpha: stabilizationAlpha ?? this.stabilizationAlpha,
      enableStabilization: enableStabilization ?? this.enableStabilization,
      rejectCollapsedHands: rejectCollapsedHands ?? this.rejectCollapsedHands,
      collapsedEpsilon: collapsedEpsilon ?? this.collapsedEpsilon,
    );
  }
}
