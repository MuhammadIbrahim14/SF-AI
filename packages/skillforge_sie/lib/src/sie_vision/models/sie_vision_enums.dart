/// Handedness label aligned with MediaPipe semantics.
enum SieHandedness {
  /// Left hand.
  left,

  /// Right hand.
  right,

  /// Backend did not report handedness.
  unknown,
}

/// Vision tracking coarse state (not gesture FSM).
enum SieVisionTrackingState {
  /// Backend idle / not started.
  idle,

  /// Initializing model / WASM / native runtime.
  initializing,

  /// Ready but not consuming frames.
  ready,

  /// Consuming frames; no hand yet.
  searching,

  /// At least one hand with usable confidence.
  tracking,

  /// Recently lost hand; still searching briefly.
  recovering,

  /// Sustained absence of hands.
  lost,

  /// Backend error.
  error,

  /// Disposed.
  disposed,
}

/// Backend implementation identity for diagnostics.
enum SieVisionBackendKind {
  /// MediaPipe Hand Landmarker (production).
  mediaPipeHandLandmarker,

  /// Deterministic mock for tests.
  mock,

  /// Platform without a wired MediaPipe adapter.
  unsupported,
}
