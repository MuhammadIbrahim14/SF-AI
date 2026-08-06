import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Immutable interaction intent event — canonical for Cursor / Pointer Bridge.
final class SieIntentEvent {
  /// Creates an intent event.
  const SieIntentEvent({
    required this.timestamp,
    required this.frameSequence,
    required this.kind,
    required this.phase,
    required this.sourceGesture,
    required this.confidence,
    required this.trackingState,
    required this.securityLevel,
    required this.routeKind,
    required this.policyId,
    this.progress = 0,
    this.axisDelta = 0,
    this.position,
    this.targetId,
    this.suppressed = false,
    this.suppressionReason,
    this.metadata = const {},
  });

  /// Timestamp (preserved).
  final DateTime timestamp;

  /// Frame sequence.
  final int frameSequence;

  /// Intent kind.
  final SieIntentKind kind;

  /// Phase.
  final SieIntentPhase phase;

  /// Source gesture kind.
  final SieGestureKind? sourceGesture;

  /// Confidence.
  final double confidence;

  /// Tracking state.
  final SieTrackingReliabilityState trackingState;

  /// Security level at emission.
  final SieSecurityLevel securityLevel;

  /// Route kind.
  final SieRouteCapabilityKind routeKind;

  /// Intent policy id.
  final SieIntentPolicyId policyId;

  /// Progress (arming / dwell).
  final double progress;

  /// Scroll / future axis delta.
  final double axisDelta;

  /// Cursor / tip position.
  final SieSpatialPoint2D? position;

  /// Hover / select target id.
  final String? targetId;

  /// Whether this event records a suppression (diagnostic).
  final bool suppressed;

  /// Suppression reason when [suppressed].
  final SieIntentSuppressionReason? suppressionReason;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Whether this is an actionable (non-suppressed) intent.
  bool get isActionable => !suppressed;
}

/// Frame-level intent snapshot.
final class SieIntentFrameSnapshot {
  /// Creates snapshot.
  const SieIntentFrameSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.mode,
    required this.events,
    required this.processingMs,
    required this.securityLevel,
    required this.routeKind,
    required this.policyId,
    this.primaryKind,
    this.suppressedCount = 0,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Frame sequence.
  final int frameSequence;

  /// Coarse mode.
  final SieInteractionMode mode;

  /// Events this frame (actionable + optional suppression diagnostics).
  final List<SieIntentEvent> events;

  /// Processing ms.
  final double processingMs;

  /// Security level.
  final SieSecurityLevel securityLevel;

  /// Route.
  final SieRouteCapabilityKind routeKind;

  /// Policy.
  final SieIntentPolicyId policyId;

  /// Primary actionable kind.
  final SieIntentKind? primaryKind;

  /// How many candidates were suppressed.
  final int suppressedCount;

  /// Actionable events only.
  List<SieIntentEvent> get actionable =>
      events.where((e) => e.isActionable).toList(growable: false);
}
