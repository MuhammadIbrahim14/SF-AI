/// Fused per-source confidence values in [0, 1].
final class SieConfidenceSources {
  /// Creates sources.
  const SieConfidenceSources({
    required this.vision,
    required this.landmarkQuality,
    required this.landmarkCompleteness,
    required this.calibrationValidity,
    required this.temporalStability,
    required this.trackingContinuity,
  });

  /// Zeroed sources (no hand / invalid).
  static const SieConfidenceSources zero = SieConfidenceSources(
    vision: 0,
    landmarkQuality: 0,
    landmarkCompleteness: 0,
    calibrationValidity: 0,
    temporalStability: 0,
    trackingContinuity: 0,
  );

  /// Vision / hand detection confidence.
  final double vision;

  /// Landmark geometric quality (visibility / presence / dead-zone).
  final double landmarkQuality;

  /// Completeness (expected landmark count).
  final double landmarkCompleteness;

  /// Calibration profile validity.
  final double calibrationValidity;

  /// Temporal stability score.
  final double temporalStability;

  /// Continuity of tracking across recent frames.
  final double trackingContinuity;

  /// Weakest-link overall (IDS §6).
  double get weakestLink {
    final values = [
      vision,
      landmarkQuality,
      landmarkCompleteness,
      calibrationValidity,
      temporalStability,
      trackingContinuity,
    ];
    var min = values.first;
    for (final v in values) {
      if (v < min) min = v;
    }
    return min.clamp(0.0, 1.0).toDouble();
  }

  /// Soft mean (diagnostic only — gating uses [weakestLink]).
  double get mean {
    return ((vision +
                landmarkQuality +
                landmarkCompleteness +
                calibrationValidity +
                temporalStability +
                trackingContinuity) /
            6)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

/// Recovery grace status (ADR-016).
final class SieRecoveryStatus {
  /// Creates recovery status.
  const SieRecoveryStatus({
    required this.inRecovery,
    required this.elapsedMs,
    required this.remainingMs,
    required this.commitsSuppressed,
  });

  /// Not recovering.
  static const SieRecoveryStatus none = SieRecoveryStatus(
    inRecovery: false,
    elapsedMs: 0,
    remainingMs: 0,
    commitsSuppressed: false,
  );

  /// Currently in Recovering state.
  final bool inRecovery;

  /// Elapsed recovery time.
  final double elapsedMs;

  /// Remaining grace before commits allowed.
  final double remainingMs;

  /// Select/Drag/Scroll commits must be suppressed.
  final bool commitsSuppressed;
}
