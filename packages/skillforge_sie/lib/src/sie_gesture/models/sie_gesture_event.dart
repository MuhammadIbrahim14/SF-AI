import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Immutable gesture event — canonical for Intent / Cursor downstream.
final class SieGestureEvent {
  /// Creates a gesture event.
  const SieGestureEvent({
    required this.timestamp,
    required this.frameSequence,
    required this.kind,
    required this.phase,
    required this.confidence,
    required this.trackingState,
    required this.handId,
    required this.durationMs,
    required this.policyId,
    this.progress = 0,
    this.axisDelta = 0,
    this.position,
    this.metadata = const {},
  });

  /// Vision / confidence timestamp (preserved).
  final DateTime timestamp;

  /// Frame sequence (preserved).
  final int frameSequence;

  /// Gesture kind.
  final SieGestureKind kind;

  /// FSM phase for this event.
  final SieGesturePhase phase;

  /// Recognition confidence [0,1].
  final double confidence;

  /// Tracking reliability at emission.
  final SieTrackingReliabilityState trackingState;

  /// Source hand id.
  final int handId;

  /// Time spent in current gesture arc (ms).
  final double durationMs;

  /// Active gesture policy.
  final SieGesturePolicyId policyId;

  /// Arming / dwell progress [0,1] when applicable.
  final double progress;

  /// Scroll / swipe signed delta (normalized) when applicable.
  final double axisDelta;

  /// Index tip position when relevant.
  final SieSpatialPoint2D? position;

  /// Diagnostic metadata (no PII / no landmark dumps).
  final Map<String, Object?> metadata;
}

/// Frame-level gesture snapshot (primary activity + optional events).
final class SieGestureFrameSnapshot {
  /// Creates a frame snapshot.
  const SieGestureFrameSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.trackingState,
    required this.activity,
    required this.primaryKind,
    required this.primaryPhase,
    required this.events,
    required this.processingMs,
    required this.policyId,
    this.armingProgress = 0,
    this.dwellProgress = 0,
    this.candidateKind,
    this.tipPosition,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Frame sequence.
  final int frameSequence;

  /// Tracking state.
  final SieTrackingReliabilityState trackingState;

  /// Coarse activity.
  final SieGestureActivity activity;

  /// Winning primary kind (null if none).
  final SieGestureKind? primaryKind;

  /// Primary phase.
  final SieGesturePhase primaryPhase;

  /// Events emitted this frame (0..N).
  final List<SieGestureEvent> events;

  /// Processing time.
  final double processingMs;

  /// Policy id.
  final SieGesturePolicyId policyId;

  /// Pinch arm progress.
  final double armingProgress;

  /// Dwell progress.
  final double dwellProgress;

  /// Competing candidate (diagnostic).
  final SieGestureKind? candidateKind;

  /// Index tip in screen logical pixels (for continuous moveCursor).
  final SieSpatialPoint2D? tipPosition;

  /// Whether any event fired.
  bool get hasEvents => events.isNotEmpty;
}
