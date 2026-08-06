/// Intent Engine enums — official interaction lexicon (IDS §7).
library;

/// Official Version 1 interaction intents.
enum SieIntentKind {
  /// Continuous cursor locomotion.
  moveCursor,

  /// Pointer entered interactive target.
  hoverEnter,

  /// Pointer exited interactive target.
  hoverExit,

  /// Primary select / click commit.
  select,

  /// Select sustained (pressed).
  selectHold,

  /// Select released.
  selectRelease,

  /// Drag started after movement threshold.
  beginDrag,

  /// Drag position update.
  updateDrag,

  /// Drag completed.
  endDrag,

  /// Cancel armed / drag / select.
  cancel,

  /// Scroll delta (does not scroll UI).
  scrollDelta,

  /// Pause SIE session.
  pauseSie,

  /// Resume SIE session.
  resumeSie,

  /// Accessibility dwell select.
  dwellSelect,

  /// Future-ready — not activated in v1.
  zoomDelta,

  /// Future-ready — not activated in v1.
  rotateDelta,

  /// Future-ready — not activated in v1.
  navigateRelative,
}

/// Intent FSM phase.
enum SieIntentPhase {
  /// Idle.
  idle,

  /// Candidate forming.
  candidate,

  /// Ready to activate.
  ready,

  /// Active / moving / dragging.
  active,

  /// Released cleanly.
  released,

  /// Prepared (e.g. drag primed).
  prepared,

  /// Completed.
  completed,

  /// Cancelled / suppressed.
  cancelled,

  /// Stopped (locomotion).
  stopped,
}

/// IDS assurance / security levels.
enum SieSecurityLevel {
  /// L0 public / marketing.
  l0Public,

  /// L1 standard dashboards.
  l1Standard,

  /// L2 elevated edits.
  l2Elevated,

  /// L3 sensitive — no gesture commit.
  l3Sensitive,

  /// L4 irreversible — SIE activate/confirm disabled.
  l4Irreversible,
}

/// Coarse route capability presets.
enum SieRouteCapabilityKind {
  /// Marketing / demos.
  marketing,

  /// Standard dashboard.
  dashboard,

  /// Course content.
  courses,

  /// Admin surfaces.
  admin,

  /// Authentication.
  authentication,

  /// Payment flows.
  payment,

  /// Custom host-defined.
  custom,
}

/// Coarse interaction mode for Riverpod.
enum SieInteractionMode {
  /// Idle / none.
  idle,

  /// Moving cursor.
  moving,

  /// Hovering.
  hovering,

  /// Selecting / pressed.
  selecting,

  /// Dragging.
  dragging,

  /// Scrolling.
  scrolling,

  /// Paused.
  paused,

  /// Blocked by policy / security.
  blocked,
}

/// Intent engine health.
enum SieIntentEngineHealth {
  /// Not started.
  idle,

  /// Ready.
  healthy,

  /// Soft issues.
  degraded,

  /// Fatal.
  error,

  /// Disposed.
  disposed,
}

/// Named intent policy (permissions only — not gesture recognition).
enum SieIntentPolicyId {
  /// Standard IDS.
  standard,

  /// Accessibility (dwell allowed).
  accessibility,

  /// Restricted (limited verbs).
  restricted,

  /// Debug (permissive logging aids).
  debug,
}

/// Why an intent was suppressed.
enum SieIntentSuppressionReason {
  /// Security level forbids.
  securityPolicy,

  /// Route capability forbids.
  routePolicy,

  /// Intent policy forbids.
  intentPolicy,

  /// Tracking / recovering / lost.
  trackingState,

  /// SIE paused or disabled.
  sessionPaused,

  /// Future intent not activated.
  futureNotActivated,

  /// Missing hover target when required.
  hoverRequired,

  /// Competing higher-priority intent.
  conflict,

  /// Invalid / corrupt input.
  invalidInput,
}
