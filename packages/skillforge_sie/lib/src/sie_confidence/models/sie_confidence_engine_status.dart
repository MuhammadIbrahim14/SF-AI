import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Low-frequency confidence engine status (Riverpod-safe).
final class SieConfidenceEngineStatus {
  /// Creates status.
  const SieConfidenceEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.trackingState,
    required this.policy,
    this.lastOverallConfidence = 0,
    this.lastStabilityScore = 0,
    this.lastError,
    this.lastEvent,
  });

  /// Idle default.
  factory SieConfidenceEngineStatus.idle() => const SieConfidenceEngineStatus(
        health: SieConfidenceEngineHealth.idle,
        initialized: false,
        running: false,
        trackingState: SieTrackingReliabilityState.disabled,
        policy: SieConfidencePolicy.standard,
      );

  /// Engine health.
  final SieConfidenceEngineHealth health;

  /// Whether initialized.
  final bool initialized;

  /// Whether consuming calibrated snapshots.
  final bool running;

  /// Current tracking reliability state.
  final SieTrackingReliabilityState trackingState;

  /// Active policy.
  final SieConfidencePolicy policy;

  /// Last overall confidence (diagnostic summary only).
  final double lastOverallConfidence;

  /// Last stability score.
  final double lastStabilityScore;

  /// Last error.
  final SieFailure? lastError;

  /// Last event label.
  final String? lastEvent;

  /// Active policy id.
  SieConfidencePolicyId get policyId => policy.id;

  /// Copy with overrides.
  SieConfidenceEngineStatus copyWith({
    SieConfidenceEngineHealth? health,
    bool? initialized,
    bool? running,
    SieTrackingReliabilityState? trackingState,
    SieConfidencePolicy? policy,
    double? lastOverallConfidence,
    double? lastStabilityScore,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieConfidenceEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      trackingState: trackingState ?? this.trackingState,
      policy: policy ?? this.policy,
      lastOverallConfidence:
          lastOverallConfidence ?? this.lastOverallConfidence,
      lastStabilityScore: lastStabilityScore ?? this.lastStabilityScore,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics for the Confidence Engine.
final class SieConfidenceEngineMetrics {
  /// Creates metrics.
  const SieConfidenceEngineMetrics({
    this.framesProcessed = 0,
    this.framesRejected = 0,
    this.lostTrackingCount = 0,
    this.recoveryCount = 0,
    this.averageConfidence = 0,
    this.lastConfidence = 0,
    this.averageStability = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
    this.thresholdEnterEvents = 0,
    this.thresholdExitEvents = 0,
  });

  /// Frames processed.
  final int framesProcessed;

  /// Invalid / rejected frames.
  final int framesRejected;

  /// LostTracking transitions.
  final int lostTrackingCount;

  /// Recovery completions (Recovering → Tracking).
  final int recoveryCount;

  /// Mean overall confidence.
  final double averageConfidence;

  /// Last overall confidence.
  final double lastConfidence;

  /// Mean stability.
  final double averageStability;

  /// Mean processing ms.
  final double averageProcessingMs;

  /// Last processing ms.
  final double lastProcessingMs;

  /// Hysteresis enter events.
  final int thresholdEnterEvents;

  /// Hysteresis exit events.
  final int thresholdExitEvents;

  /// Frame rejection rate [0,1].
  double get frameRejectionRate {
    if (framesProcessed == 0) return 0;
    return framesRejected / framesProcessed;
  }

  /// Copy with overrides.
  SieConfidenceEngineMetrics copyWith({
    int? framesProcessed,
    int? framesRejected,
    int? lostTrackingCount,
    int? recoveryCount,
    double? averageConfidence,
    double? lastConfidence,
    double? averageStability,
    double? averageProcessingMs,
    double? lastProcessingMs,
    int? thresholdEnterEvents,
    int? thresholdExitEvents,
  }) {
    return SieConfidenceEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      framesRejected: framesRejected ?? this.framesRejected,
      lostTrackingCount: lostTrackingCount ?? this.lostTrackingCount,
      recoveryCount: recoveryCount ?? this.recoveryCount,
      averageConfidence: averageConfidence ?? this.averageConfidence,
      lastConfidence: lastConfidence ?? this.lastConfidence,
      averageStability: averageStability ?? this.averageStability,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
      thresholdEnterEvents: thresholdEnterEvents ?? this.thresholdEnterEvents,
      thresholdExitEvents: thresholdExitEvents ?? this.thresholdExitEvents,
    );
  }
}
