/// Confidence Engine enums — tracking reliability only (not gesture FSM).
library;

/// IDS-aligned tracking reliability states (Confidence Engine scope).
enum SieTrackingReliabilityState {
  /// Engine / session off.
  disabled,

  /// Running; no usable hand yet.
  idle,

  /// Hand present; usable for locomotion at baseline confidence.
  tracking,

  /// High confidence + temporal stability.
  stable,

  /// Low confidence / instability; limited verbs downstream.
  degraded,

  /// Hand missing; intents suppressed.
  lostTracking,

  /// Reacquired; grace before commits (ADR-016).
  recovering,

  /// Hard failure.
  error,
}

/// Per-frame validation outcome.
enum SieConfidenceFrameValidation {
  /// Safe for full downstream consumption.
  valid,

  /// Borderline; consume per policy (often locomotion-only).
  weak,

  /// Oscillating / noisy; mayConsume typically false.
  unstable,

  /// Rejected (corrupt / missing / below floor).
  invalid,
}

/// Named confidence policy (thresholds only).
enum SieConfidencePolicyId {
  /// Balanced defaults.
  standard,

  /// Stricter enter thresholds.
  precision,

  /// More tolerant thresholds (a11y).
  accessibility,

  /// Loose thresholds for engineering overlays.
  debug,
}

/// Confidence engine health.
enum SieConfidenceEngineHealth {
  /// Not started.
  idle,

  /// Ready / processing.
  healthy,

  /// Soft issues (degraded tracking prolonged).
  degraded,

  /// Fatal.
  error,

  /// Disposed.
  disposed,
}
