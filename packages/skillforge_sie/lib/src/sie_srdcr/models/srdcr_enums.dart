/// Service Registry & Dependency Composition Root vocabulary.
library;

/// Registered SIE service identifiers.
enum SrdcrServiceId {
  /// Configuration & Policy Management Framework.
  cpmf,

  /// Diagnostics (SIDF).
  diagnostics,

  /// Platform capability / detector surface.
  platform,

  /// Camera engine.
  camera,

  /// Vision provider.
  vision,

  /// Landmark engine.
  landmarks,

  /// Spatial coordinate engine.
  spatial,

  /// Calibration engine.
  calibration,

  /// Confidence engine.
  confidence,

  /// Gesture engine.
  gestures,

  /// Intent engine.
  intent,

  /// Virtual cursor engine.
  cursor,

  /// Flutter pointer bridge.
  pointer,

  /// Input arbitration.
  arbitration,

  /// Interaction orchestrator.
  orchestrator,

  /// Integration framework.
  integration,

  /// Progressive rollout framework.
  rollout,
}

/// Service lifetime.
enum SrdcrLifetime {
  /// One instance for the registry lifetime.
  singleton,

  /// One instance per bootstrap scope.
  scoped,

  /// New instance per resolve (rare for engines).
  transient,
}

/// Composition root lifecycle phase.
enum SrdcrPhase {
  /// Not started.
  idle,

  /// Registering services.
  registering,

  /// Validating dependency graph.
  validating,

  /// Constructing services.
  constructing,

  /// Running startup pipeline.
  starting,

  /// Ready for host use.
  ready,

  /// Shutting down.
  shuttingDown,

  /// Disposed.
  disposed,

  /// Failed.
  failed,
}

/// Framework health.
enum SrdcrHealth {
  /// Idle.
  idle,

  /// Healthy.
  healthy,

  /// Degraded.
  degraded,

  /// Failed startup.
  failed,

  /// Disposed.
  disposed,
}
