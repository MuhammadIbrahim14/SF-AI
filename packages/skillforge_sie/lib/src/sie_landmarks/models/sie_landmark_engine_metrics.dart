/// Engineering metrics for the Landmark Engine (not production UI).
final class SieLandmarkEngineMetrics {
  /// Creates metrics.
  const SieLandmarkEngineMetrics({
    this.framesProcessed = 0,
    this.framesEmpty = 0,
    this.handsAccepted = 0,
    this.handsRejected = 0,
    this.handsDegraded = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
    this.validationSuccessRate = 1,
    this.stabilityScore = 1,
  });

  /// Vision results consumed.
  final int framesProcessed;

  /// Frames with zero hands.
  final int framesEmpty;

  /// Hands that passed as valid.
  final int handsAccepted;

  /// Hands rejected.
  final int handsRejected;

  /// Hands accepted as degraded (e.g. clamped).
  final int handsDegraded;

  /// Mean processing time.
  final double averageProcessingMs;

  /// Last processing time.
  final double lastProcessingMs;

  /// accepted / (accepted + rejected), 1 if none yet.
  final double validationSuccessRate;

  /// Heuristic 0–1 from recent EMA deltas (1 = very stable).
  final double stabilityScore;

  /// Copy with overrides.
  SieLandmarkEngineMetrics copyWith({
    int? framesProcessed,
    int? framesEmpty,
    int? handsAccepted,
    int? handsRejected,
    int? handsDegraded,
    double? averageProcessingMs,
    double? lastProcessingMs,
    double? validationSuccessRate,
    double? stabilityScore,
  }) {
    return SieLandmarkEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      framesEmpty: framesEmpty ?? this.framesEmpty,
      handsAccepted: handsAccepted ?? this.handsAccepted,
      handsRejected: handsRejected ?? this.handsRejected,
      handsDegraded: handsDegraded ?? this.handsDegraded,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
      validationSuccessRate:
          validationSuccessRate ?? this.validationSuccessRate,
      stabilityScore: stabilityScore ?? this.stabilityScore,
    );
  }
}
