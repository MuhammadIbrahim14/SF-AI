/// Gesture Engine enums — IDS vocabulary only (v1).
library;

/// Official Version 1.0 gesture kinds (IDS G01–G09).
enum SieGestureKind {
  /// G01 — open hand / point locomotion.
  openHandPoint,

  /// G02 — pinch arming (not Select).
  pinchArm,

  /// G03 — primary Select commit.
  pinchCommit,

  /// G04 — sustain pressed / hold.
  pinchHold,

  /// G05 — pinch release.
  pinchRelease,

  /// G06 — scroll intent (does not scroll).
  scrollIntent,

  /// G07 — fist cancel.
  fistCancel,

  /// G08 — optional swipe navigation (feature-flagged).
  swipeNavigation,

  /// G09 — dwell select (accessibility only).
  dwellSelect,
}

/// Gesture FSM phase (kind-specific subset).
enum SieGesturePhase {
  /// No activity.
  idle,

  /// Temporal candidate forming.
  candidate,

  /// Pinch arming progress.
  arming,

  /// Discrete recognition fired.
  recognized,

  /// Continuous maintenance (point / hold).
  maintained,

  /// Pinch commit completed this event.
  committed,

  /// Pinch held after commit.
  held,

  /// Release completed.
  released,

  /// Continuous active modality (scroll).
  active,

  /// Modality completed cleanly.
  completed,

  /// Cancelled / aborted.
  cancelled,
}

/// Coarse engine-level gesture activity for Riverpod.
enum SieGestureActivity {
  /// No primary gesture.
  none,

  /// Open-hand pointing / locomotion hypothesis.
  pointing,

  /// Pinch arming.
  arming,

  /// Pinch pressed (commit/hold).
  pressed,

  /// Scroll intent active.
  scrolling,

  /// Fist cancel recognized.
  cancelling,

  /// Dwell in progress / fired.
  dwelling,

  /// Swipe recognized.
  swiping,
}

/// Gesture engine health.
enum SieGestureEngineHealth {
  /// Not started.
  idle,

  /// Ready / processing.
  healthy,

  /// Soft issues.
  degraded,

  /// Fatal.
  error,

  /// Disposed.
  disposed,
}

/// Named gesture policy (thresholds / feature flags only).
enum SieGesturePolicyId {
  /// Standard IDS defaults.
  standard,

  /// Stricter arm/commit.
  precision,

  /// More tolerant (a11y-friendly timings).
  accessibility,

  /// Debug / loose.
  debug,
}
