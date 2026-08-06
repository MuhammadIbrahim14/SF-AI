/// SIE Integration Framework enums.
library;

/// Framework lifecycle phase.
enum SieIntegrationPhase {
  /// Not registered.
  unregistered,

  /// Registered, not initialized.
  registered,

  /// Initializing policies / capabilities.
  initializing,

  /// Ready for host use.
  ready,

  /// SIE actively enabled.
  active,

  /// Paused (app background / host pause).
  paused,

  /// Gracefully degraded (traditional only).
  degraded,

  /// Shutting down.
  shuttingDown,

  /// Disposed.
  disposed,
}

/// Framework health.
enum SieIntegrationHealth {
  /// Idle / not ready.
  idle,

  /// Healthy.
  healthy,

  /// Degraded (SIE off, app continues).
  degraded,

  /// Error.
  error,

  /// Disposed.
  disposed,
}

/// Route SIE mode (host-facing policy).
enum SieRouteSieMode {
  /// Full SIE where security allows.
  enabled,

  /// Limited SIE (e.g. browse / hover only).
  limited,

  /// Restricted (elevated security; hover-required selects).
  restricted,

  /// Fully disabled on this route.
  disabled,

  /// Host-configurable (settings).
  configurable,
}

/// SkillForge / host application modules (extensible).
enum SieAppModuleId {
  /// Student module.
  student,

  /// Teacher.
  teacher,

  /// Freelancer.
  freelancer,

  /// Company.
  company,

  /// Admin.
  admin,

  /// Marketplace.
  marketplace,

  /// Courses.
  courses,

  /// Assessments.
  assessments,

  /// AI assistant.
  aiAssistant,

  /// Custom / unknown.
  custom,
}

/// Integration-level feature toggles (host-facing; not MediaPipe).
enum SieIntegrationFeatureId {
  /// Hover targets.
  hover,

  /// Click / select.
  click,

  /// Drag.
  drag,

  /// Scroll.
  scroll,

  /// Dwell select.
  dwell,

  /// Accessibility modes.
  accessibility,

  /// Large cursor preference.
  largeCursor,

  /// Reduced motion.
  reducedMotion,

  /// Debug overlay (SIDF).
  debugOverlay,
}

/// Degradation reason (graceful).
enum SieDegradationReason {
  /// None.
  none,

  /// Camera unavailable.
  cameraUnavailable,

  /// Vision / hand tracking unavailable.
  visionUnavailable,

  /// Permission denied / revoked.
  permissionDenied,

  /// Platform unsupported.
  platformUnsupported,

  /// Feature flags disabled.
  featureDisabled,

  /// Host disabled SIE.
  hostDisabled,

  /// Route policy disabled SIE.
  routeDisabled,

  /// Security level forbids SIE (L4).
  securityRestricted,
}
