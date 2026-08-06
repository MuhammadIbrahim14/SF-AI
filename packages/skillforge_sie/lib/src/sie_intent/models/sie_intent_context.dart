import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Immutable interaction context for intent decisions.
final class SieIntentContext {
  /// Creates context.
  const SieIntentContext({
    required this.route,
    required this.securityLevel,
    required this.policy,
    this.trackingState = SieTrackingReliabilityState.idle,
    this.sieEnabled = true,
    this.paused = false,
    this.platformAllowsSie = true,
    this.hoveredTargetId,
    this.dragThreshold = 48,
    this.gestureReady = true,
    this.commitsSuppressed = false,
  });

  /// Default dashboard context.
  factory SieIntentContext.dashboard() => const SieIntentContext(
        route: SieRouteCapability.dashboard,
        securityLevel: SieSecurityLevel.l1Standard,
        policy: SieIntentPolicy.standard,
      );

  /// Active route capability.
  final SieRouteCapability route;

  /// Effective security level (may override route default).
  final SieSecurityLevel securityLevel;

  /// Intent policy.
  final SieIntentPolicy policy;

  /// Latest tracking reliability.
  final SieTrackingReliabilityState trackingState;

  /// Host SIE enabled flag.
  final bool sieEnabled;

  /// Session paused.
  final bool paused;

  /// Platform capability allows SIE.
  final bool platformAllowsSie;

  /// Current hovered target id (host / cursor supplied).
  final String? hoveredTargetId;

  /// Drag distance threshold in **screen logical pixels** (not normalized).
  /// Must sit above Flutter tap slop (~18) so pinch clicks don't become drags.
  final double dragThreshold;

  /// Confidence gesture-ready.
  final bool gestureReady;

  /// Confidence commits suppressed (Recovering).
  final bool commitsSuppressed;

  /// Copy with overrides.
  SieIntentContext copyWith({
    SieRouteCapability? route,
    SieSecurityLevel? securityLevel,
    SieIntentPolicy? policy,
    SieTrackingReliabilityState? trackingState,
    bool? sieEnabled,
    bool? paused,
    bool? platformAllowsSie,
    String? hoveredTargetId,
    bool clearHover = false,
    double? dragThreshold,
    bool? gestureReady,
    bool? commitsSuppressed,
  }) {
    return SieIntentContext(
      route: route ?? this.route,
      securityLevel: securityLevel ?? this.securityLevel,
      policy: policy ?? this.policy,
      trackingState: trackingState ?? this.trackingState,
      sieEnabled: sieEnabled ?? this.sieEnabled,
      paused: paused ?? this.paused,
      platformAllowsSie: platformAllowsSie ?? this.platformAllowsSie,
      hoveredTargetId:
          clearHover ? null : (hoveredTargetId ?? this.hoveredTargetId),
      dragThreshold: dragThreshold ?? this.dragThreshold,
      gestureReady: gestureReady ?? this.gestureReady,
      commitsSuppressed: commitsSuppressed ?? this.commitsSuppressed,
    );
  }
}

/// Candidate intent before policy gating.
final class SieIntentCandidate {
  /// Creates candidate.
  const SieIntentCandidate({
    required this.kind,
    required this.phase,
    required this.confidence,
    required this.sourceGesture,
    this.priority = 50,
    this.progress = 0,
    this.axisDelta = 0,
    this.position,
    this.targetId,
    this.metadata = const {},
  });

  /// Intent kind.
  final SieIntentKind kind;

  /// Phase.
  final SieIntentPhase phase;

  /// Confidence.
  final double confidence;

  /// Source gesture name / kind string.
  final String sourceGesture;

  /// Lower = higher priority.
  final int priority;

  /// Progress.
  final double progress;

  /// Axis delta.
  final double axisDelta;

  /// Position.
  final SieSpatialPoint2D? position;

  /// Hover / select target.
  final String? targetId;

  /// Metadata.
  final Map<String, Object?> metadata;
}
