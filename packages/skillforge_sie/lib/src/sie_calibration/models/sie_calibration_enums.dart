/// Calibration schema / session / sensitivity enums.
library;

/// Dominant-hand preference for calibration.
enum SieCalibratedHandedness {
  /// Prefer right hand.
  right,

  /// Prefer left hand.
  left,

  /// Follow vision detection (manual override wins when set).
  auto,
}

/// Posture hint (standing reserved for future).
enum SieUserPosture {
  /// Sitting (v1 default).
  sitting,

  /// Standing (future-ready).
  standing,
}

/// Sensitivity profile — affects calibration gains only, not gestures.
enum SieSensitivityProfileId {
  /// Balanced default.
  standard,

  /// Lower gain, larger dead zones.
  precision,

  /// Higher gain for faster reach.
  fast,

  /// Larger targets / softer edges (a11y).
  accessibility,

  /// Extra damping / larger dead zones (tremor).
  tremorTolerant,
}

/// Guided calibration session phase.
enum SieCalibrationSessionPhase {
  /// No session.
  idle,

  /// First-run flow.
  firstRun,

  /// Full manual recalibration.
  manualRecalibration,

  /// Partial update of a subset of fields.
  partialRecalibration,

  /// Validating samples / profile.
  validating,

  /// Session completed successfully.
  complete,

  /// Session failed or cancelled.
  failed,
}

/// Why recalibration is recommended (never auto-applied).
enum SieRecalibrationReason {
  /// User asked.
  userRequested,

  /// Camera device changed.
  cameraChanged,

  /// Window / logical size changed.
  windowResized,

  /// Device orientation changed.
  orientationChanged,

  /// Host flagged lighting / environment metadata.
  environmentChanged,

  /// Device / platform changed.
  deviceChanged,

  /// Calibration missing or corrupt.
  missingOrCorrupt,
}

/// Calibration engine health.
enum SieCalibrationEngineHealth {
  /// Not started.
  idle,

  /// Ready / processing.
  healthy,

  /// Using defaults or soft issues.
  degraded,

  /// Fatal.
  error,

  /// Disposed.
  disposed,
}

/// Calibration availability for hosts.
enum SieCalibrationAvailability {
  /// No usable profile (identity defaults in use).
  missing,

  /// Defaults / identity profile active.
  defaults,

  /// Persisted or session-built profile active.
  ready,

  /// Guided session in progress.
  calibrating,
}
