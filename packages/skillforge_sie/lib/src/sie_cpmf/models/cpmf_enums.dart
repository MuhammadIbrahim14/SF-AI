/// Configuration & Policy Management Framework vocabulary.
library;

/// Schema / compatibility version for CPMF bundles.
const int kCpmfSchemaVersion = 1;

/// Configuration domain identifiers.
enum CpmfDomainId {
  /// Camera.
  camera,

  /// Vision.
  vision,

  /// Landmarks.
  landmarks,

  /// Spatial coordinates.
  coordinates,

  /// Calibration.
  calibration,

  /// Confidence.
  confidence,

  /// Gestures.
  gestures,

  /// Cursor.
  cursor,

  /// Pointer bridge.
  pointer,

  /// Input arbitration.
  arbitration,

  /// Interaction orchestrator.
  orchestrator,

  /// Accessibility.
  accessibility,

  /// Diagnostics / SIDF.
  diagnostics,

  /// Security (IDS).
  security,

  /// Performance.
  performance,

  /// Rollout defaults.
  rollout,
}

/// Environment profile.
enum CpmfEnvironment {
  /// Local development.
  development,

  /// Automated tests.
  testing,

  /// QA.
  qa,

  /// Staging.
  staging,

  /// Production.
  production,

  /// Enterprise tenant.
  enterprise,

  /// Experimental lab.
  experimental,
}

/// Named user / accessibility / role profiles (composable).
enum CpmfProfileId {
  /// Default.
  standard,

  /// Reduced motion.
  reducedMotion,

  /// High contrast (appearance preference).
  highContrast,

  /// Large cursor.
  largeCursor,

  /// Tremor support.
  tremorSupport,

  /// Dwell mode.
  dwellMode,

  /// Left-handed.
  leftHanded,

  /// Seated mode.
  seatedMode,

  /// Developer.
  developer,

  /// QA.
  qa,

  /// Beta tester.
  betaTester,

  /// Enterprise customer.
  enterpriseCustomer,

  /// Administrator.
  administrator,

  /// Accessibility composite.
  accessibility,
}

/// Framework health.
enum CpmfHealth {
  /// Not loaded.
  idle,

  /// Healthy.
  healthy,

  /// Using fallback after validation issues.
  degraded,

  /// Error.
  error,

  /// Disposed.
  disposed,
}

/// Configuration source precedence (highest last wins).
enum CpmfConfigSource {
  /// Built-in defaults.
  builtIn,

  /// Local file / asset.
  localFile,

  /// Environment profile.
  environment,

  /// Build-time / flavor.
  buildTime,

  /// Runtime host overrides.
  runtime,

  /// Future remote provider.
  remote,
}

/// Policy question ids (deterministic evaluation).
enum CpmfPolicyQuestion {
  /// Can SIE operate on this route?
  sieOperableOnRoute,

  /// Can pinch / select activate here?
  pinchActivateAllowed,

  /// Should cursor snapping be enabled?
  snappingEnabled,

  /// Should prediction be reduced?
  predictionReduced,

  /// Should animations be disabled?
  animationsDisabled,

  /// Should dwell select be available?
  dwellSelectAllowed,

  /// Should drag be allowed?
  dragAllowed,
}

/// Validation severity.
enum CpmfValidationSeverity {
  /// Informational.
  info,

  /// Warning (fallback applied).
  warning,

  /// Error (rejected; use safe defaults).
  error,
}
