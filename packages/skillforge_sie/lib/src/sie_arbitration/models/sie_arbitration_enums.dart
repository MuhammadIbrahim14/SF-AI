/// Input Arbitration Engine enums — ownership & policy vocabulary.
library;

/// Version 1 + future-ready input sources.
enum SieInputSource {
  /// No owner.
  none,

  /// Physical mouse / trackpad.
  mouse,

  /// Touch / trackpad touch.
  touch,

  /// Keyboard focus navigation.
  keyboard,

  /// Spatial Interaction Engine (virtual cursor).
  sie,

  /// Future — voice commands.
  voice,

  /// Future — eye tracking.
  eyeTracking,

  /// Future — XR controllers.
  xr,

  /// Future — stylus.
  stylus,

  /// Future — game controller.
  gameController,

  /// Future — AI assistant.
  aiAssistant,

  /// Future — external a11y devices.
  accessibilityDevice,
}

/// Arbitration strategy.
enum SieArbitrationPolicyId {
  /// Newest valid activity becomes owner.
  lastActiveWins,

  /// Owner fixed until explicit release.
  lockedOwnership,

  /// Host/user-selected owner.
  manualOverride,

  /// Accessibility devices / modes get priority.
  accessibilityPriority,

  /// Route / application allowlist drives ownership.
  applicationPolicy,
}

/// Why ownership changed (or was retained).
enum SieOwnershipReason {
  /// Initial / idle.
  none,

  /// Source acquired ownership.
  acquired,

  /// Owner released voluntarily.
  released,

  /// Conflict resolved in favour of a source.
  conflictResolved,

  /// Route forbids previous owner.
  routeRestricted,

  /// Device became unavailable.
  deviceUnavailable,

  /// SIE LostTracking forced release.
  lostTracking,

  /// Session / app paused.
  paused,

  /// Window focus lost.
  focusLost,

  /// Permission revoked.
  permissionRevoked,

  /// Locked policy retained owner.
  locked,

  /// Manual override applied.
  manual,

  /// Policy switch forced re-evaluation.
  policyChanged,

  /// Traditional supremacy (ADR-019).
  traditionalSupremacy,
}

/// Engine health.
enum SieArbitrationEngineHealth {
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

/// Coarse claim / activity kind from a modality.
enum SieInputActivityKind {
  /// Presence / idle heartbeat.
  presence,

  /// Pointer / cursor move.
  move,

  /// Press / key down / select.
  press,

  /// Release.
  release,

  /// Scroll.
  scroll,

  /// Focus change.
  focus,

  /// Explicit release of ownership claim.
  releaseOwnership,

  /// Device disconnected / unavailable.
  disconnect,

  /// LostTracking (SIE).
  lostTracking,

  /// Recovering (SIE).
  recovering,
}

/// Whether a source is Version 1 active vs future-only.
extension SieInputSourceX on SieInputSource {
  /// Version 1 modalities that may own pointer interaction.
  bool get isVersion1 =>
      this == SieInputSource.none ||
      this == SieInputSource.mouse ||
      this == SieInputSource.touch ||
      this == SieInputSource.keyboard ||
      this == SieInputSource.sie;

  /// Future modality (interface only in v1).
  bool get isFuture => !isVersion1 && this != SieInputSource.none;

  /// Traditional (non-SIE) input — ADR-019 supremacy class.
  bool get isTraditional =>
      this == SieInputSource.mouse ||
      this == SieInputSource.touch ||
      this == SieInputSource.keyboard;
}
