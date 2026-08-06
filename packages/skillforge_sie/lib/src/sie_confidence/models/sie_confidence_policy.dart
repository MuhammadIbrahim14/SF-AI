import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';

/// Enter/exit hysteresis thresholds and temporal persistence (tunable).
///
/// Relative ordering is normative (ADR-015); exact floats are implementation detail.
final class SieConfidenceThresholds {
  /// Creates thresholds.
  const SieConfidenceThresholds({
    required this.trackEnter,
    required this.trackExit,
    required this.stableEnter,
    required this.stableExit,
    required this.degradedEnter,
    required this.degradedExit,
    required this.gestureReadyEnter,
    required this.gestureReadyExit,
    required this.recoveryEnter,
    required this.invalidFloor,
    required this.weakFloor,
    required this.stabilityEnter,
    required this.stabilityExit,
    required this.enterFrames,
    required this.exitFrames,
    required this.recoverMs,
    required this.lostMs,
    required this.stabilityWindow,
    required this.stabilityDeltaLimit,
    required this.noiseSpikeLimit,
  });

  /// Confidence to enter Tracking.
  final double trackEnter;

  /// Confidence to exit Tracking → LostTracking.
  final double trackExit;

  /// Confidence (+ stability) to enter Stable.
  final double stableEnter;

  /// Exit Stable → Tracking.
  final double stableExit;

  /// Below this (but above trackExit) → Degraded.
  final double degradedEnter;

  /// Exit Degraded upward.
  final double degradedExit;

  /// Gesture-ready enter (not gesture recognition).
  final double gestureReadyEnter;

  /// Gesture-ready exit.
  final double gestureReadyExit;

  /// Min confidence to leave Recovering after grace.
  final double recoveryEnter;

  /// Below → invalid frame.
  final double invalidFloor;

  /// Below → weak frame (if above invalid).
  final double weakFloor;

  /// Temporal stability score to enter Stable.
  final double stabilityEnter;

  /// Stability score exit from Stable.
  final double stabilityExit;

  /// Frames of persistence for enter transitions.
  final int enterFrames;

  /// Frames of persistence for exit / loss.
  final int exitFrames;

  /// T_recover grace period (ms) — IDS 400–700.
  final int recoverMs;

  /// Sustained absence (ms) before LostTracking from idle flicker.
  final int lostMs;

  /// Temporal window size (frames).
  final int stabilityWindow;

  /// Max mean tip delta (normalized) considered stable.
  final double stabilityDeltaLimit;

  /// Absolute confidence jump suppressed as spike.
  final double noiseSpikeLimit;

  /// Whether hysteresis bands are valid (enter > exit).
  bool get isValid =>
      trackEnter > trackExit &&
      stableEnter > stableExit &&
      gestureReadyEnter > gestureReadyExit &&
      recoveryEnter >= trackExit &&
      weakFloor > invalidFloor &&
      enterFrames >= 1 &&
      exitFrames >= 1 &&
      recoverMs > 0 &&
      stabilityWindow >= 2;

  /// Standard policy thresholds.
  static const SieConfidenceThresholds standard = SieConfidenceThresholds(
    trackEnter: 0.40,
    trackExit: 0.28,
    stableEnter: 0.65,
    stableExit: 0.50,
    degradedEnter: 0.38,
    degradedExit: 0.48,
    gestureReadyEnter: 0.50,
    gestureReadyExit: 0.38,
    recoveryEnter: 0.45,
    invalidFloor: 0.12,
    weakFloor: 0.30,
    stabilityEnter: 0.55,
    stabilityExit: 0.40,
    enterFrames: 2,
    exitFrames: 4,
    recoverMs: 350,
    lostMs: 180,
    stabilityWindow: 8,
    stabilityDeltaLimit: 0.06,
    noiseSpikeLimit: 0.40,
  );

  /// Precision — stricter.
  static const SieConfidenceThresholds precision = SieConfidenceThresholds(
    trackEnter: 0.62,
    trackExit: 0.48,
    stableEnter: 0.85,
    stableExit: 0.72,
    degradedEnter: 0.58,
    degradedExit: 0.66,
    gestureReadyEnter: 0.80,
    gestureReadyExit: 0.65,
    recoveryEnter: 0.68,
    invalidFloor: 0.20,
    weakFloor: 0.50,
    stabilityEnter: 0.80,
    stabilityExit: 0.62,
    enterFrames: 4,
    exitFrames: 5,
    recoverMs: 650,
    lostMs: 100,
    stabilityWindow: 10,
    stabilityDeltaLimit: 0.030,
    noiseSpikeLimit: 0.28,
  );

  /// Accessibility — more tolerant.
  static const SieConfidenceThresholds accessibility = SieConfidenceThresholds(
    trackEnter: 0.48,
    trackExit: 0.32,
    stableEnter: 0.70,
    stableExit: 0.55,
    degradedEnter: 0.45,
    degradedExit: 0.55,
    gestureReadyEnter: 0.60,
    gestureReadyExit: 0.45,
    recoveryEnter: 0.52,
    invalidFloor: 0.10,
    weakFloor: 0.35,
    stabilityEnter: 0.60,
    stabilityExit: 0.45,
    enterFrames: 2,
    exitFrames: 5,
    recoverMs: 700,
    lostMs: 160,
    stabilityWindow: 6,
    stabilityDeltaLimit: 0.060,
    noiseSpikeLimit: 0.40,
  );

  /// Debug — loose.
  static const SieConfidenceThresholds debug = SieConfidenceThresholds(
    trackEnter: 0.35,
    trackExit: 0.20,
    stableEnter: 0.55,
    stableExit: 0.40,
    degradedEnter: 0.30,
    degradedExit: 0.40,
    gestureReadyEnter: 0.45,
    gestureReadyExit: 0.30,
    recoveryEnter: 0.40,
    invalidFloor: 0.05,
    weakFloor: 0.25,
    stabilityEnter: 0.40,
    stabilityExit: 0.25,
    enterFrames: 1,
    exitFrames: 2,
    recoverMs: 300,
    lostMs: 80,
    stabilityWindow: 4,
    stabilityDeltaLimit: 0.080,
    noiseSpikeLimit: 0.50,
  );

  /// Lookup by policy id.
  static SieConfidenceThresholds forPolicy(SieConfidencePolicyId id) {
    return switch (id) {
      SieConfidencePolicyId.standard => standard,
      SieConfidencePolicyId.precision => precision,
      SieConfidencePolicyId.accessibility => accessibility,
      SieConfidencePolicyId.debug => debug,
    };
  }
}

/// Active confidence policy wrapper.
final class SieConfidencePolicy {
  /// Creates a policy.
  const SieConfidencePolicy({
    required this.id,
    required this.thresholds,
  });

  /// Standard.
  static const SieConfidencePolicy standard = SieConfidencePolicy(
    id: SieConfidencePolicyId.standard,
    thresholds: SieConfidenceThresholds.standard,
  );

  /// Policy id.
  final SieConfidencePolicyId id;

  /// Threshold set.
  final SieConfidenceThresholds thresholds;

  /// Build from id.
  factory SieConfidencePolicy.fromId(SieConfidencePolicyId id) {
    return SieConfidencePolicy(
      id: id,
      thresholds: SieConfidenceThresholds.forPolicy(id),
    );
  }
}
