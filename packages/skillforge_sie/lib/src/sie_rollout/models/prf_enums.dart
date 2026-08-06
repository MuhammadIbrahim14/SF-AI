/// Progressive Rollout Framework vocabulary.
library;

/// User segment for staged deployment.
enum PrfUserSegment {
  /// Internal developers.
  internalDevelopers,

  /// QA.
  qaTeam,

  /// Beta testers.
  betaTesters,

  /// Public users.
  publicUsers,

  /// Premium.
  premiumUsers,

  /// Enterprise.
  enterpriseCustomers,

  /// Administrators.
  administrators,
}

/// Platform rollout maturity.
enum PrfPlatformMaturity {
  /// Fully stable.
  stable,

  /// Beta cohort.
  beta,

  /// Experimental.
  experimental,

  /// Explicitly disabled.
  disabled,
}

/// Canary phase percentages (ordered).
enum PrfCanaryPhase {
  /// Off / not in canary.
  off,

  /// 1%.
  p1,

  /// 5%.
  p5,

  /// 10%.
  p10,

  /// 25%.
  p25,

  /// 50%.
  p50,

  /// 100%.
  p100,
}

/// Extension for canary percentage.
extension PrfCanaryPhaseX on PrfCanaryPhase {
  /// Percent of population (0–100).
  int get percent => switch (this) {
        PrfCanaryPhase.off => 0,
        PrfCanaryPhase.p1 => 1,
        PrfCanaryPhase.p5 => 5,
        PrfCanaryPhase.p10 => 10,
        PrfCanaryPhase.p25 => 25,
        PrfCanaryPhase.p50 => 50,
        PrfCanaryPhase.p100 => 100,
      };

  /// Next phase (or self at 100%).
  PrfCanaryPhase get next => switch (this) {
        PrfCanaryPhase.off => PrfCanaryPhase.p1,
        PrfCanaryPhase.p1 => PrfCanaryPhase.p5,
        PrfCanaryPhase.p5 => PrfCanaryPhase.p10,
        PrfCanaryPhase.p10 => PrfCanaryPhase.p25,
        PrfCanaryPhase.p25 => PrfCanaryPhase.p50,
        PrfCanaryPhase.p50 => PrfCanaryPhase.p100,
        PrfCanaryPhase.p100 => PrfCanaryPhase.p100,
      };
}

/// Rollout decision outcome.
enum PrfRolloutDecision {
  /// SIE enabled.
  enable,

  /// SIE disabled (traditional only).
  disable,

  /// Held pending healthier telemetry / canary.
  hold,

  /// Rolled back due to quality.
  rollback,

  /// Kill switch active.
  killSwitch,
}

/// Why SIE was rejected / disabled.
enum PrfRejectionReason {
  /// None — eligible.
  none,

  /// Kill switch.
  killSwitch,

  /// Master feature flag off.
  featureFlagDisabled,

  /// Platform policy.
  platformRejected,

  /// Device capability.
  deviceRejected,

  /// User segment not in rollout.
  segmentRejected,

  /// Route policy.
  routeRejected,

  /// Canary cohort not selected.
  canaryExcluded,

  /// Telemetry below threshold.
  telemetryUnhealthy,

  /// Automatic rollback.
  rollback,

  /// Configuration error.
  configurationError,

  /// Integration / host disabled.
  hostDisabled,
}

/// Framework health.
enum PrfHealth {
  /// Idle.
  idle,

  /// Healthy rollout active.
  healthy,

  /// Degraded / traditional fallback.
  degraded,

  /// Kill switch / emergency.
  emergency,

  /// Error.
  error,

  /// Disposed.
  disposed,
}

/// A/B experiment cohort.
enum PrfExperimentCohort {
  /// Control / standard cursor.
  groupA,

  /// Treatment / adaptive cursor.
  groupB,

  /// Not in experiment.
  none,
}

/// Configuration source (precedence: remote > runtime > build > local).
enum PrfConfigSource {
  /// Built-in defaults.
  localDefaults,

  /// Compile-time / flavor.
  buildTime,

  /// Runtime host overrides.
  runtime,

  /// Future remote config.
  remote,
}

/// Independent PRF feature flag ids.
enum PrfFeatureFlagId {
  /// Master enable SIE.
  enableSie,

  /// Experimental gestures.
  experimentalGestures,

  /// Two-hand tracking.
  twoHandTracking,

  /// Eye tracking (future — off).
  eyeTracking,

  /// Voice control (future — off).
  voiceControl,

  /// Debug overlay.
  debugOverlay,

  /// Accessibility features.
  accessibilityFeatures,

  /// Beta features pack.
  betaFeatures,
}
