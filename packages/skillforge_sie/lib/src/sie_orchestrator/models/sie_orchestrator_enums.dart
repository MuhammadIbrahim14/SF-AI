/// Interaction Orchestrator enums — application interaction coordination.
library;

/// Application / session lifecycle for interaction delivery.
enum SieAppLifecycleState {
  /// Not started.
  cold,

  /// Startup in progress.
  starting,

  /// Fully interactive foreground.
  resumed,

  /// Temporarily paused (still in memory).
  paused,

  /// Backgrounded.
  background,

  /// Returning to foreground.
  foregrounding,

  /// Shutting down.
  shuttingDown,

  /// Disposed.
  shutdown,
}

/// Coarse interaction delivery mode (Riverpod-safe).
enum SieOrchestrationMode {
  /// Interaction disabled.
  disabled,

  /// Traditional input only (SIE gated off).
  traditionalOnly,

  /// SIE pointer stream may be dispatched.
  sieActive,

  /// Mixed / transitioning.
  coordinating,

  /// Recovering after loss / error.
  recovering,

  /// Modal surface active (policy may restrict).
  modal,
}

/// Focus ownership kind.
enum SieFocusKind {
  /// No focus tracked.
  none,

  /// Window has OS focus.
  window,

  /// Hover-driven focus candidate.
  hover,

  /// Keyboard / a11y focus.
  keyboard,

  /// Modal / dialog focus trap.
  modal,

  /// Overlay focus.
  overlay,
}

/// Modal surface kind (host-reported).
enum SieModalKind {
  /// No modal.
  none,

  /// Dialog.
  dialog,

  /// Bottom sheet.
  sheet,

  /// Popup / menu.
  popup,

  /// Tooltip.
  tooltip,

  /// Context menu.
  contextMenu,
}

/// Orchestrator health.
enum SieOrchestratorHealth {
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

/// Why a dispatch was gated / allowed.
enum SieDispatchDecision {
  /// Forwarded to Flutter.
  dispatched,

  /// Blocked — lifecycle.
  blockedLifecycle,

  /// Blocked — no window focus.
  blockedFocus,

  /// Blocked — interaction disabled.
  blockedDisabled,

  /// Blocked — SIE not owner / not forwarded.
  blockedArbitration,

  /// Blocked — feature gated.
  blockedFeature,

  /// Blocked — route / security.
  blockedRoute,

  /// Blocked — modal policy.
  blockedModal,

  /// Dropped — empty batch.
  skippedEmpty,
}
