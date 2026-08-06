import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_hand_feature_extractor.dart';

/// Internal hypothesis from a classifier this frame.
final class SieGestureHypothesis {
  /// Creates hypothesis.
  const SieGestureHypothesis({
    required this.kind,
    required this.phase,
    required this.confidence,
    required this.priority,
    this.progress = 0,
    this.axisDelta = 0,
    this.emit = false,
    this.durationMs = 0,
  });

  /// Kind.
  final SieGestureKind kind;

  /// Phase.
  final SieGesturePhase phase;

  /// Confidence.
  final double confidence;

  /// IDS priority (lower = higher priority).
  final int priority;

  /// Progress.
  final double progress;

  /// Axis delta.
  final double axisDelta;

  /// Whether to emit an event this frame.
  final bool emit;

  /// Duration.
  final double durationMs;
}

/// Shared step context.
final class SieGestureStepContext {
  /// Creates context.
  const SieGestureStepContext({
    required this.timestamp,
    required this.frameSequence,
    required this.timestampMs,
    required this.features,
    required this.trackingState,
    required this.overallConfidence,
    required this.gestureReady,
    required this.commitsSuppressed,
    required this.mayConsume,
    required this.policy,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Frame sequence.
  final int frameSequence;

  /// Epoch ms.
  final double timestampMs;

  /// Features.
  final SieHandGestureFeatures features;

  /// Tracking state.
  final SieTrackingReliabilityState trackingState;

  /// Overall confidence.
  final double overallConfidence;

  /// Gesture-ready gate.
  final bool gestureReady;

  /// Commits suppressed.
  final bool commitsSuppressed;

  /// May consume.
  final bool mayConsume;

  /// Policy.
  final SieGesturePolicy policy;

  /// Thresholds shortcut.
  SieGestureThresholds get t => policy.thresholds;
}

/// Classifier port.
abstract interface class SieGestureClassifier {
  /// Step one frame; return optional hypothesis.
  SieGestureHypothesis? step(SieGestureStepContext ctx);

  /// Reset FSM.
  void reset();
}

/// Build an event from hypothesis + context.
SieGestureEvent sieGestureEventFrom({
  required SieGestureStepContext ctx,
  required SieGestureHypothesis h,
}) {
  return SieGestureEvent(
    timestamp: ctx.timestamp,
    frameSequence: ctx.frameSequence,
    kind: h.kind,
    phase: h.phase,
    confidence: h.confidence,
    trackingState: ctx.trackingState,
    handId: ctx.features.handId,
    durationMs: h.durationMs,
    policyId: ctx.policy.id,
    progress: h.progress,
    axisDelta: h.axisDelta,
    position: ctx.features.valid ? ctx.features.indexTipScreen : null,
    metadata: {
      'pinchDistance': ctx.features.pinchDistance,
      'openness': ctx.features.openness,
      'fistCurl': ctx.features.fistCurl,
    },
  );
}
