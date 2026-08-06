/// Virtual Cursor Engine enums — IDS cursor behaviour (Doc 03 §8).
library;

/// Canonical cursor interaction / visibility state.
enum SieCursorState {
  /// Not shown (SIE off / not initialized).
  hidden,

  /// Shown, idle / not moving this frame.
  visible,

  /// Actively translating.
  moving,

  /// Over an interactive target.
  hovering,

  /// Pinch arming / select candidate.
  armed,

  /// Select pressed.
  pressed,

  /// Drag in progress.
  dragging,

  /// Scroll modality.
  scrolling,

  /// Tracking recovery grace.
  recovering,

  /// Session paused.
  paused,

  /// Hand lost.
  lostTracking,
}

/// Cursor appearance theme (visual only — never changes behaviour).
enum SieCursorThemeId {
  /// Default product cursor.
  standard,

  /// Smaller / precise glyph.
  precision,

  /// Large / high-contrast.
  accessibility,

  /// Debug overlays enabled by host.
  debug,

  /// Presentation / demo emphasis.
  presentation,
}

/// Acceleration / motion profile (behavioural).
enum SieCursorMotionProfileId {
  /// Balanced IDS default.
  standard,

  /// Fine control near targets.
  precision,

  /// Faster large movements (disabled while Armed).
  fast,

  /// Tremor-tolerant / slower.
  accessibility,
}

/// Engine health.
enum SieCursorEngineHealth {
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

/// Visibility presentation mode.
enum SieCursorVisibilityMode {
  /// Fully hidden.
  hidden,

  /// Fading in.
  fadingIn,

  /// Fully visible.
  visible,

  /// Fading out.
  fadingOut,

  /// Dimmed (LostTracking).
  faded,

  /// Recovering pulse indicator (host draws).
  recovering,
}
