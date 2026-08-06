import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';

/// Tunable gesture thresholds (relative ordering normative; floats tunable).
final class SieGestureThresholds {
  /// Creates thresholds.
  const SieGestureThresholds({
    required this.pinchArmEnter,
    required this.pinchArmExit,
    required this.pinchCommitEnter,
    required this.pinchCommitExit,
    required this.pinchHoldEnter,
    required this.openHandPinchMin,
    required this.fistCurlMax,
    required this.fistPinchMax,
    required this.armMinMs,
    required this.commitMinMs,
    required this.reclickMs,
    required this.pointStableMs,
    required this.scrollDeadzone,
    required this.scrollActivateVelocity,
    required this.scrollMinMs,
    required this.fistMinMs,
    required this.swipeMinVelocity,
    required this.swipeMinDistance,
    required this.dwellMs,
    required this.historyFrames,
    required this.enterFrames,
    required this.exitFrames,
  });

  /// Pinch distance enter arm zone (normalized).
  final double pinchArmEnter;

  /// Pinch distance exit arm zone (hysteresis, larger).
  final double pinchArmExit;

  /// Pinch distance for commit (tighter than arm).
  final double pinchCommitEnter;

  /// Pinch distance release hysteresis.
  final double pinchCommitExit;

  /// Hold may use slightly looser distance (anti-chatter).
  final double pinchHoldEnter;

  /// Min pinch distance to consider open hand.
  final double openHandPinchMin;

  /// Max mean tip-to-mcp curl for fist (normalized).
  final double fistCurlMax;

  /// Max pinch distance while fist.
  final double fistPinchMax;

  /// Minimum arming duration before commit eligible (ms).
  final int armMinMs;

  /// Minimum time at commit distance (ms).
  final int commitMinMs;

  /// Refractory after commit before next commit (ms).
  final int reclickMs;

  /// Open-hand stable duration (ms).
  final int pointStableMs;

  /// Scroll vertical dead zone (normalized / frame).
  final double scrollDeadzone;

  /// Scroll activation velocity (normalized / ms).
  final double scrollActivateVelocity;

  /// Scroll candidate persistence (ms).
  final int scrollMinMs;

  /// Fist recognition persistence (ms).
  final int fistMinMs;

  /// Swipe minimum velocity.
  final double swipeMinVelocity;

  /// Swipe minimum travel (normalized).
  final double swipeMinDistance;

  /// Dwell select duration (ms).
  final int dwellMs;

  /// Feature history length.
  final int historyFrames;

  /// Temporal enter frames.
  final int enterFrames;

  /// Temporal exit frames.
  final int exitFrames;

  /// Whether bands are valid.
  bool get isValid =>
      pinchArmEnter > pinchCommitEnter &&
      pinchArmExit > pinchArmEnter &&
      pinchCommitExit > pinchCommitEnter &&
      pinchHoldEnter >= pinchCommitEnter &&
      armMinMs > 0 &&
      commitMinMs > 0 &&
      reclickMs > 0 &&
      historyFrames >= 3 &&
      enterFrames >= 1 &&
      exitFrames >= 1;

  /// Standard IDS-inspired defaults (tuned for live webcam noise).
  static const SieGestureThresholds standard = SieGestureThresholds(
    pinchArmEnter: 0.16,
    pinchArmExit: 0.22,
    pinchCommitEnter: 0.09,
    pinchCommitExit: 0.14,
    pinchHoldEnter: 0.12,
    openHandPinchMin: 0.18,
    fistCurlMax: 0.07,
    fistPinchMax: 0.08,
    armMinMs: 220,
    commitMinMs: 80,
    reclickMs: 320,
    pointStableMs: 60,
    scrollDeadzone: 0.008,
    scrollActivateVelocity: 0.0002,
    scrollMinMs: 60,
    fistMinMs: 120,
    swipeMinVelocity: 0.0012,
    swipeMinDistance: 0.18,
    dwellMs: 900,
    historyFrames: 12,
    enterFrames: 2,
    exitFrames: 3,
  );

  /// Precision — slower / stricter.
  static const SieGestureThresholds precision = SieGestureThresholds(
    pinchArmEnter: 0.11,
    pinchArmExit: 0.15,
    pinchCommitEnter: 0.045,
    pinchCommitExit: 0.075,
    pinchHoldEnter: 0.060,
    openHandPinchMin: 0.15,
    fistCurlMax: 0.075,
    fistPinchMax: 0.09,
    armMinMs: 160,
    commitMinMs: 70,
    reclickMs: 450,
    pointStableMs: 100,
    scrollDeadzone: 0.010,
    scrollActivateVelocity: 0.00040,
    scrollMinMs: 120,
    fistMinMs: 110,
    swipeMinVelocity: 0.0015,
    swipeMinDistance: 0.22,
    dwellMs: 1100,
    historyFrames: 14,
    enterFrames: 3,
    exitFrames: 4,
  );

  /// Accessibility — longer dwell, looser pinch.
  static const SieGestureThresholds accessibility = SieGestureThresholds(
    pinchArmEnter: 0.14,
    pinchArmExit: 0.18,
    pinchCommitEnter: 0.070,
    pinchCommitExit: 0.100,
    pinchHoldEnter: 0.085,
    openHandPinchMin: 0.12,
    fistCurlMax: 0.100,
    fistPinchMax: 0.12,
    armMinMs: 100,
    commitMinMs: 40,
    reclickMs: 400,
    pointStableMs: 60,
    scrollDeadzone: 0.006,
    scrollActivateVelocity: 0.00028,
    scrollMinMs: 80,
    fistMinMs: 70,
    swipeMinVelocity: 0.0010,
    swipeMinDistance: 0.15,
    dwellMs: 700,
    historyFrames: 10,
    enterFrames: 2,
    exitFrames: 3,
  );

  /// Debug — fast.
  static const SieGestureThresholds debug = SieGestureThresholds(
    pinchArmEnter: 0.15,
    pinchArmExit: 0.20,
    pinchCommitEnter: 0.080,
    pinchCommitExit: 0.110,
    pinchHoldEnter: 0.095,
    openHandPinchMin: 0.12,
    fistCurlMax: 0.110,
    fistPinchMax: 0.13,
    armMinMs: 40,
    commitMinMs: 20,
    reclickMs: 150,
    pointStableMs: 30,
    scrollDeadzone: 0.004,
    scrollActivateVelocity: 0.00020,
    scrollMinMs: 40,
    fistMinMs: 40,
    swipeMinVelocity: 0.0008,
    swipeMinDistance: 0.12,
    dwellMs: 400,
    historyFrames: 8,
    enterFrames: 1,
    exitFrames: 2,
  );

  /// Lookup by policy.
  static SieGestureThresholds forPolicy(SieGesturePolicyId id) {
    return switch (id) {
      SieGesturePolicyId.standard => standard,
      SieGesturePolicyId.precision => precision,
      SieGesturePolicyId.accessibility => accessibility,
      SieGesturePolicyId.debug => debug,
    };
  }
}

/// Gesture policy — feature flags + thresholds.
final class SieGesturePolicy {
  /// Creates policy.
  const SieGesturePolicy({
    required this.id,
    required this.thresholds,
    this.swipeNavigationEnabled = false,
    this.dwellSelectEnabled = false,
  });

  /// Standard (swipe off, dwell off).
  static const SieGesturePolicy standard = SieGesturePolicy(
    id: SieGesturePolicyId.standard,
    thresholds: SieGestureThresholds.standard,
  );

  /// Policy id.
  final SieGesturePolicyId id;

  /// Thresholds.
  final SieGestureThresholds thresholds;

  /// G08 feature flag (disabled by default).
  final bool swipeNavigationEnabled;

  /// G09 accessibility flag.
  final bool dwellSelectEnabled;

  /// Build from id with optional flags.
  factory SieGesturePolicy.fromId(
    SieGesturePolicyId id, {
    bool? swipeNavigationEnabled,
    bool? dwellSelectEnabled,
  }) {
    final base = SieGesturePolicy(
      id: id,
      thresholds: SieGestureThresholds.forPolicy(id),
      swipeNavigationEnabled: swipeNavigationEnabled ?? false,
      dwellSelectEnabled: dwellSelectEnabled ??
          (id == SieGesturePolicyId.accessibility),
    );
    return base;
  }

  /// Copy with overrides.
  SieGesturePolicy copyWith({
    SieGesturePolicyId? id,
    SieGestureThresholds? thresholds,
    bool? swipeNavigationEnabled,
    bool? dwellSelectEnabled,
  }) {
    return SieGesturePolicy(
      id: id ?? this.id,
      thresholds: thresholds ?? this.thresholds,
      swipeNavigationEnabled:
          swipeNavigationEnabled ?? this.swipeNavigationEnabled,
      dwellSelectEnabled: dwellSelectEnabled ?? this.dwellSelectEnabled,
    );
  }
}
