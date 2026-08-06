/// Rolling diagnostics for the Vision Provider (engineering only).
final class SieVisionMetrics {
  /// Creates metrics.
  const SieVisionMetrics({
    this.detectionFps = 0,
    this.inferenceFps = 0,
    this.averageInferenceMs = 0,
    this.lastInferenceMs = 0,
    this.lastConfidence = 0,
    this.framesReceived = 0,
    this.framesInferred = 0,
    this.framesDropped = 0,
    this.noHandCount = 0,
  });

  /// Results emitted per second (approx).
  final double detectionFps;

  /// Inferences completed per second (approx).
  final double inferenceFps;

  /// EMA / mean inference time.
  final double averageInferenceMs;

  /// Last inference duration.
  final double lastInferenceMs;

  /// Last primary-hand confidence (0 if none).
  final double lastConfidence;

  /// Camera frames observed.
  final int framesReceived;

  /// Frames sent through the backend.
  final int framesInferred;

  /// Frames skipped under load.
  final int framesDropped;

  /// Consecutive / cumulative no-hand results (diagnostic).
  final int noHandCount;

  /// Copy with overrides.
  SieVisionMetrics copyWith({
    double? detectionFps,
    double? inferenceFps,
    double? averageInferenceMs,
    double? lastInferenceMs,
    double? lastConfidence,
    int? framesReceived,
    int? framesInferred,
    int? framesDropped,
    int? noHandCount,
  }) {
    return SieVisionMetrics(
      detectionFps: detectionFps ?? this.detectionFps,
      inferenceFps: inferenceFps ?? this.inferenceFps,
      averageInferenceMs: averageInferenceMs ?? this.averageInferenceMs,
      lastInferenceMs: lastInferenceMs ?? this.lastInferenceMs,
      lastConfidence: lastConfidence ?? this.lastConfidence,
      framesReceived: framesReceived ?? this.framesReceived,
      framesInferred: framesInferred ?? this.framesInferred,
      framesDropped: framesDropped ?? this.framesDropped,
      noHandCount: noHandCount ?? this.noHandCount,
    );
  }
}
