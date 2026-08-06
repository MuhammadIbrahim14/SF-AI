/// Flutter Pointer Bridge enums — Flutter-compatible pointer semantics.
library;

/// High-level pointer lifecycle (Riverpod-safe).
enum SiePointerLifecycleState {
  /// No SIE pointer.
  absent,

  /// Pointer added; not interacting.
  idle,

  /// Hovering / moving without buttons.
  hovering,

  /// Primary button down.
  pressed,

  /// Dragging (down + move).
  dragging,

  /// Scroll modality active.
  scrolling,

  /// Cancelled (LostTracking / Cancel intent).
  cancelled,
}

/// Discrete bridge event kinds (map 1:1 to Flutter pointer kinds).
enum SiePointerEventKind {
  /// Pointer entered the hit-test arena.
  added,

  /// Hover move (no buttons).
  hover,

  /// Move (optionally while pressed).
  move,

  /// Primary button down.
  down,

  /// Primary button up.
  up,

  /// Scroll signal.
  scroll,

  /// Cancel active gesture (Flutter PointerCancel).
  cancel,

  /// Pointer left the arena.
  removed,
}

/// Bridge engine health.
enum SiePointerBridgeHealth {
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

/// Which mouse button mask (Flutter-compatible).
abstract final class SiePointerButtons {
  /// No buttons.
  static const int none = 0;

  /// Primary / left (Flutter kPrimaryButton).
  static const int primary = 0x01;

  /// Secondary / right.
  static const int secondary = 0x02;

  /// Middle.
  static const int middle = 0x04;
}
