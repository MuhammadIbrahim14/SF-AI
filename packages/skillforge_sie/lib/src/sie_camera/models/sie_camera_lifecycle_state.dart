/// Deterministic Camera Engine lifecycle states.
enum SieCameraLifecycleState {
  /// No resources held.
  idle,

  /// Enumerating devices.
  discovering,

  /// Controller initialized; not streaming.
  ready,

  /// Transitioning to stream.
  starting,

  /// Emitting frames.
  streaming,

  /// Initialized; stream paused (no frames).
  paused,

  /// Stopping stream / tearing down controller.
  stopping,

  /// Recoverable or terminal error (see status.error).
  error,

  /// Permanently released; must create a new engine instance to reuse.
  disposed,
}

/// Extension helpers.
extension SieCameraLifecycleStateX on SieCameraLifecycleState {
  /// Whether frames may be emitted.
  bool get isStreaming => this == SieCameraLifecycleState.streaming;

  /// Whether [start] is a valid next action.
  bool get canStart =>
      this == SieCameraLifecycleState.ready ||
      this == SieCameraLifecycleState.paused ||
      this == SieCameraLifecycleState.error;

  /// Whether resources are still owned.
  bool get isActive =>
      this != SieCameraLifecycleState.idle &&
      this != SieCameraLifecycleState.disposed;
}
