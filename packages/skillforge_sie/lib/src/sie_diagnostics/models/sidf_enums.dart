/// SIDF enums — debug & diagnostics vocabulary (engineering only).
library;

/// Pipeline stages observable by SIDF.
enum SidfPipelineStage {
  /// Platform capability.
  platform,

  /// Camera engine.
  camera,

  /// Vision provider.
  vision,

  /// Landmark engine.
  landmarks,

  /// Spatial coordinates.
  spatial,

  /// Calibration.
  calibration,

  /// Confidence.
  confidence,

  /// Gesture.
  gesture,

  /// Intent.
  intent,

  /// Virtual cursor.
  cursor,

  /// Pointer bridge.
  pointer,

  /// Input arbitration.
  arbitration,

  /// Interaction orchestrator.
  orchestrator,
}

/// Stage health for pipeline inspector.
enum SidfStageHealth {
  /// Unknown / not sampled.
  unknown,

  /// Healthy.
  healthy,

  /// Degraded.
  degraded,

  /// Error.
  error,

  /// Idle / not running.
  idle,

  /// Disabled by feature/platform.
  disabled,
}

/// Timeline event categories.
enum SidfTimelineCategory {
  /// Lifecycle / session.
  lifecycle,

  /// Camera.
  camera,

  /// Vision / tracking.
  vision,

  /// Gesture.
  gesture,

  /// Intent.
  intent,

  /// Cursor.
  cursor,

  /// Pointer.
  pointer,

  /// Arbitration.
  arbitration,

  /// Orchestration.
  orchestration,

  /// Error / recovery.
  error,

  /// Performance spike.
  performance,
}

/// Structured log levels.
enum SidfLogLevel {
  /// Finest.
  trace,

  /// Debug.
  debug,

  /// Info.
  info,

  /// Warning.
  warning,

  /// Error.
  error,
}

/// SIDF framework health.
enum SidfFrameworkHealth {
  /// Disabled / idle.
  idle,

  /// Active observing.
  active,

  /// Recording.
  recording,

  /// Error.
  error,

  /// Disposed.
  disposed,
}
