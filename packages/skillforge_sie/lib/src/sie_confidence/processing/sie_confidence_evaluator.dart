import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_snapshot.dart';
import 'package:skillforge_sie/src/sie_confidence/processing/sie_confidence_fusion.dart';
import 'package:skillforge_sie/src/sie_confidence/processing/sie_tracking_state_machine.dart';

/// Orchestrates fusion, smoothing, validation, and tracking state.
final class SieConfidenceEvaluator {
  /// Creates evaluator.
  SieConfidenceEvaluator({
    required SieConfidencePolicy policy,
    SieConfidenceFusion fusion = const SieConfidenceFusion(),
  })  : _policy = policy,
        _fusion = fusion,
        _stability = SieTemporalStabilityTracker(
          windowSize: policy.thresholds.stabilityWindow,
        ),
        _smoother = SieConfidenceSmoother(),
        _machine = SieTrackingStateMachine(
          thresholds: policy.thresholds,
        );

  SieConfidencePolicy _policy;
  final SieConfidenceFusion _fusion;
  late SieTemporalStabilityTracker _stability;
  final SieConfidenceSmoother _smoother;
  final SieTrackingStateMachine _machine;

  /// Active policy.
  SieConfidencePolicy get policy => _policy;

  /// Current tracking state.
  SieTrackingReliabilityState get trackingState => _machine.state;

  /// Apply a new policy (thresholds only).
  void setPolicy(SieConfidencePolicy policy) {
    if (!policy.thresholds.isValid) {
      throw ArgumentError('Invalid confidence thresholds');
    }
    _policy = policy;
    _machine.applyThresholds(policy.thresholds);
    _stability = SieTemporalStabilityTracker(
      windowSize: policy.thresholds.stabilityWindow,
    );
  }

  /// Enable / disable.
  void setEnabled(bool enabled) => _machine.setEnabled(enabled);

  /// Reset temporal state.
  void reset() {
    _stability.reset();
    _smoother.reset();
    _machine.reset();
  }

  /// Signal hard error.
  void setError() => _machine.setError();

  /// Clear error.
  void clearError() => _machine.clearError();

  /// Evaluate one calibrated frame.
  ({
    SieConfidenceFrameSnapshot snapshot,
    SieTrackingStateStep step,
  }) evaluate(SieCalibratedFrameSnapshot input) {
    final t = _policy.thresholds;
    final tip = input.primaryHand?.indexFingertip?.normalizedCalibrated;
    _stability.push(tip);

    final temporal = _stability.stabilityScore(t.stabilityDeltaLimit);
    final continuity = _stability.continuityScore();

    final sources = _fusion.fuse(
      frame: input,
      temporalStability: temporal,
      trackingContinuity: continuity,
      thresholds: t,
    );

    final rawOverall = sources.weakestLink;
    final smoothed = _smoother.update(rawOverall, t.noiseSpikeLimit);

    final hasHand = input.hasHand;
    final step = _machine.step(
      hasHand: hasHand,
      confidence: smoothed,
      stability: temporal,
      now: input.timestamp.toUtc(),
    );

    final validation = _validate(
      hasHand: hasHand,
      confidence: smoothed,
      temporal: temporal,
      thresholds: t,
      state: step.state,
    );

    final mayConsume = _mayConsume(validation, step.state);

    final snapshot = SieConfidenceFrameSnapshot(
      timestamp: input.timestamp,
      frameSequence: input.frameSequence,
      visionTrackingState: input.visionTrackingState,
      trackingState: step.state,
      overallConfidence: smoothed,
      sources: sources,
      temporalStabilityScore: temporal,
      frameValidation: validation,
      policyId: _policy.id,
      recovery: step.recovery,
      gestureReady: step.gestureReady && mayConsume,
      mayConsume: mayConsume,
      processingMs: 0, // filled by engine
      // Always forward hands when present so the cursor can follow the tip
      // during track-acquire (idle). Commits still require [mayConsume].
      hands: hasHand ? List.unmodifiable(input.hands) : const [],
      profile: input.profile,
      viewWidth: input.viewWidth,
      viewHeight: input.viewHeight,
      smoothedConfidence: smoothed,
    );

    return (snapshot: snapshot, step: step);
  }

  static SieConfidenceFrameValidation _validate({
    required bool hasHand,
    required double confidence,
    required double temporal,
    required SieConfidenceThresholds thresholds,
    required SieTrackingReliabilityState state,
  }) {
    if (confidence.isNaN || confidence.isInfinite) {
      return SieConfidenceFrameValidation.invalid;
    }
    if (!hasHand ||
        state == SieTrackingReliabilityState.lostTracking ||
        state == SieTrackingReliabilityState.disabled ||
        state == SieTrackingReliabilityState.error) {
      if (!hasHand) {
        return SieConfidenceFrameValidation.invalid;
      }
      return SieConfidenceFrameValidation.invalid;
    }
    // Hand visible but not yet latched — allow tip tracking (weak), not commits.
    if (state == SieTrackingReliabilityState.idle) {
      return SieConfidenceFrameValidation.weak;
    }
    if (confidence < thresholds.invalidFloor) {
      return SieConfidenceFrameValidation.invalid;
    }
    if (temporal < thresholds.stabilityExit * 0.5 &&
        state != SieTrackingReliabilityState.recovering) {
      return SieConfidenceFrameValidation.unstable;
    }
    if (confidence < thresholds.weakFloor ||
        state == SieTrackingReliabilityState.degraded) {
      return SieConfidenceFrameValidation.weak;
    }
    return SieConfidenceFrameValidation.valid;
  }

  static bool _mayConsume(
    SieConfidenceFrameValidation validation,
    SieTrackingReliabilityState state,
  ) {
    if (validation == SieConfidenceFrameValidation.invalid ||
        validation == SieConfidenceFrameValidation.unstable) {
      return false;
    }
    return state == SieTrackingReliabilityState.tracking ||
        state == SieTrackingReliabilityState.stable ||
        state == SieTrackingReliabilityState.degraded ||
        state == SieTrackingReliabilityState.recovering ||
        // Allow tip + soft gestures while track gate is still latching.
        (state == SieTrackingReliabilityState.idle &&
            validation == SieConfidenceFrameValidation.weak);
  }
}
