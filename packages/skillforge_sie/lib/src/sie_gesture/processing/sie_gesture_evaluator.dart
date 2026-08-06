import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_snapshot.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_classifier.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_classifiers.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_conflict_resolver.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_hand_feature_extractor.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_pinch_family_classifier.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Orchestrates classifiers + conflict resolution for one frame.
final class SieGestureEvaluator {
  /// Creates evaluator.
  SieGestureEvaluator({
    required SieGesturePolicy policy,
    SieHandFeatureExtractor extractor = const SieHandFeatureExtractor(),
    SieGestureConflictResolver resolver = const SieGestureConflictResolver(),
  }) : _policy = policy,
       _extractor = extractor,
       _resolver = resolver,
       _pinch = SiePinchFamilyClassifier(),
       _openHand = SieOpenHandPointClassifier(),
       _fist = SieFistCancelClassifier(),
       _scroll = SieScrollIntentClassifier(),
       _swipe = SieSwipeNavigationClassifier(),
       _dwell = SieDwellSelectClassifier();

  SieGesturePolicy _policy;
  final SieHandFeatureExtractor _extractor;
  final SieGestureConflictResolver _resolver;
  final SiePinchFamilyClassifier _pinch;
  final SieOpenHandPointClassifier _openHand;
  final SieFistCancelClassifier _fist;
  final SieScrollIntentClassifier _scroll;
  final SieSwipeNavigationClassifier _swipe;
  final SieDwellSelectClassifier _dwell;

  SieSpatialPoint2D? _prevTip;
  double? _prevTsMs;
  int? _activeHandId;

  /// Active policy.
  SieGesturePolicy get policy => _policy;

  /// Pinch arming progress.
  double get armingProgress => _pinch.armingProgress;

  /// Apply policy.
  void setPolicy(SieGesturePolicy policy) {
    if (!policy.thresholds.isValid) {
      throw ArgumentError('Invalid gesture thresholds');
    }
    _policy = policy;
  }

  /// Reset all FSMs.
  void reset() {
    _pinch.reset();
    _openHand.reset();
    _fist.reset();
    _scroll.reset();
    _swipe.reset();
    _dwell.reset();
    _prevTip = null;
    _prevTsMs = null;
    _activeHandId = null;
  }

  /// Evaluate one confidence snapshot.
  ({SieGestureFrameSnapshot snapshot, int conflicts}) evaluate(
    SieConfidenceFrameSnapshot input,
  ) {
    final tsMs = input.timestamp.toUtc().millisecondsSinceEpoch.toDouble();
    final safetyBlocked =
        input.trackingState == SieTrackingReliabilityState.disabled ||
        input.trackingState == SieTrackingReliabilityState.error ||
        input.trackingState == SieTrackingReliabilityState.lostTracking;

    final hand = _selectHand(input);
    final features = hand == null
        ? SieHandGestureFeatures.invalid
        : _extractor.extract(
            hand: hand,
            previousTip: _prevTip,
            previousTimestampMs: _prevTsMs,
            timestampMs: tsMs,
          );

    if (features.valid) {
      _prevTip = features.indexTip;
      _prevTsMs = tsMs;
      _activeHandId = features.handId;
    } else {
      _prevTip = null;
      _prevTsMs = null;
      _activeHandId = null;
    }

    final ctx = SieGestureStepContext(
      timestamp: input.timestamp,
      frameSequence: input.frameSequence,
      timestampMs: tsMs,
      features: features,
      trackingState: input.trackingState,
      overallConfidence: input.overallConfidence,
      gestureReady: input.gestureReady,
      commitsSuppressed: input.commitsSuppressed,
      mayConsume: input.mayConsume && !safetyBlocked,
      policy: _policy,
    );

    if (safetyBlocked || !input.mayConsume) {
      // Brief tracking gaps: keep tip tracking, but only cancel an active pinch
      // when the hand is actually gone (invalid features).
      final tip = features.valid ? features.indexTipScreen : null;
      final cancelActivePinch =
          !features.valid &&
          (_pinch.phase == SieGesturePhase.arming ||
              _pinch.phase == SieGesturePhase.held ||
              _pinch.phase == SieGesturePhase.committed);
      final cancelEvents = <SieGestureEvent>[];
      if (cancelActivePinch) {
        cancelEvents.add(
          SieGestureEvent(
            timestamp: input.timestamp,
            frameSequence: input.frameSequence,
            kind: SieGestureKind.pinchRelease,
            phase: SieGesturePhase.cancelled,
            confidence: input.overallConfidence,
            trackingState: input.trackingState,
            handId: features.handId,
            durationMs: 0,
            policyId: _policy.id,
            metadata: const {'reason': 'tracking_loss'},
          ),
        );
        reset();
      } else if (!features.valid) {
        reset();
      }
      assert(() {
        if (features.valid && input.frameSequence % 60 == 0) {
          // ignore: avoid_print
          print(
            '[sie.gesture] tip_while_gated '
            'mayConsume=${input.mayConsume} '
            'tip=${tip?.x.toStringAsFixed(1)},${tip?.y.toStringAsFixed(1)} '
            'open=${features.openness.toStringAsFixed(2)} '
            'pinch=${features.pinchDistance.toStringAsFixed(2)} '
            'phase=${_pinch.phase.name}',
          );
        }
        return true;
      }());
      return (
        snapshot: SieGestureFrameSnapshot(
          timestamp: input.timestamp,
          frameSequence: input.frameSequence,
          trackingState: input.trackingState,
          activity: tip != null && (tip.x.abs() > 1 || tip.y.abs() > 1)
              ? (_pinch.phase == SieGesturePhase.arming ||
                        _pinch.phase == SieGesturePhase.committed ||
                        _pinch.phase == SieGesturePhase.held
                    ? SieGestureActivity.arming
                    : SieGestureActivity.pointing)
              : SieGestureActivity.none,
          primaryKind: tip != null
              ? (_pinch.phase == SieGesturePhase.arming
                    ? SieGestureKind.pinchArm
                    : SieGestureKind.openHandPoint)
              : null,
          primaryPhase: tip != null
              ? SieGesturePhase.candidate
              : SieGesturePhase.idle,
          events: List.unmodifiable(cancelEvents),
          processingMs: 0,
          policyId: _policy.id,
          tipPosition: tip != null && (tip.x.abs() > 1 || tip.y.abs() > 1)
              ? tip
              : null,
        ),
        conflicts: 0,
      );
    }

    _pinch.settleRelease();

    final hypotheses = <SieGestureHypothesis>[
      ?_fist.step(ctx),
      ?_pinch.step(ctx),
      ?_dwell.step(ctx),
      ?_scroll.step(ctx),
      ?_swipe.step(ctx),
      ?_openHand.step(ctx),
    ];

    // Fist cancel forces pinch reset — but never while pinch is pressed/held.
    // Resetting mid-hold without a release left the virtual pointer stuck down.
    final fistEmit = hypotheses.any(
      (h) => h.kind == SieGestureKind.fistCancel && h.emit,
    );
    final pinchBusy =
        _pinch.phase == SieGesturePhase.arming ||
        _pinch.phase == SieGesturePhase.committed ||
        _pinch.phase == SieGesturePhase.held;
    if (fistEmit && !pinchBusy) {
      _pinch.reset();
      _scroll.reset();
      _dwell.reset();
      _swipe.reset();
    }

    final resolved = _resolver.resolve(
      hypotheses: hypotheses,
      pinch: _pinch,
      dwellProgress: _dwell.progress,
      commitsSuppressed: input.commitsSuppressed,
      safetyBlocked: false,
    );

    final events = [
      for (final h in resolved.events) sieGestureEventFrom(ctx: ctx, h: h),
    ];

    final tipScreen = features.valid ? features.indexTipScreen : null;

    return (
      snapshot: SieGestureFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        trackingState: input.trackingState,
        activity: resolved.activity,
        primaryKind: resolved.primary?.kind,
        primaryPhase: resolved.primary?.phase ?? SieGesturePhase.idle,
        events: List.unmodifiable(events),
        processingMs: 0,
        policyId: _policy.id,
        armingProgress: resolved.armingProgress,
        dwellProgress: resolved.dwellProgress,
        candidateKind: resolved.candidate?.kind,
        tipPosition: tipScreen,
      ),
      conflicts: resolved.conflictsResolved,
    );
  }

  /// Keep tracking one hand while it remains visible. MediaPipe can reorder
  /// hands between frames; following `hands.first` made the cursor jump
  /// between people/hands during a two-hand demo.
  SieCalibratedHandSnapshot? _selectHand(SieConfidenceFrameSnapshot input) {
    final activeId = _activeHandId;
    if (activeId != null) {
      for (final hand in input.hands) {
        if (hand.handId == activeId) return hand;
      }
    }
    return input.primaryHand;
  }
}
