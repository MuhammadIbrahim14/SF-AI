/// Outcome of landmark validation for a hand or frame.
enum SieLandmarkValidationState {
  /// Passed validation and available for downstream use.
  valid,

  /// No hand present (not an error).
  empty,

  /// Rejected due to integrity failure.
  rejected,

  /// Accepted with warnings (e.g. clamped coords) — still usable.
  degraded,
}

/// Why a landmark set was rejected (diagnostics only).
enum SieLandmarkRejectionReason {
  /// Wrong landmark count (not MediaPipe 21).
  invalidCount,

  /// NaN in coordinates.
  nanValue,

  /// Infinite coordinate.
  infiniteValue,

  /// Coordinates wildly out of expected domain.
  outOfRange,

  /// Duplicate / collapsed structure (all points identical).
  collapsedStructure,

  /// Corrupted or unsupported payload.
  corrupted,

  /// Unexpected backend anomaly.
  anomaly,
}

/// Landmark Engine lifecycle / health.
enum SieLandmarkEngineHealth {
  /// Not started.
  idle,

  /// Ready / processing.
  healthy,

  /// Recent rejections elevated but still running.
  degraded,

  /// Fatal / disposed.
  error,

  /// Disposed.
  disposed,
}
