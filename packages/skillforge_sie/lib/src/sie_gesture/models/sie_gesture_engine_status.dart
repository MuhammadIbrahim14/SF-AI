import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';

/// Low-frequency gesture engine status (Riverpod-safe).
final class SieGestureEngineStatus {
  /// Creates status.
  const SieGestureEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.activity,
    required this.policy,
    this.primaryKind,
    this.primaryPhase = SieGesturePhase.idle,
    this.lastError,
    this.lastEvent,
  });

  /// Idle default.
  factory SieGestureEngineStatus.idle() => const SieGestureEngineStatus(
        health: SieGestureEngineHealth.idle,
        initialized: false,
        running: false,
        activity: SieGestureActivity.none,
        policy: SieGesturePolicy.standard,
      );

  /// Health.
  final SieGestureEngineHealth health;

  /// Initialized.
  final bool initialized;

  /// Running.
  final bool running;

  /// Coarse activity.
  final SieGestureActivity activity;

  /// Active policy.
  final SieGesturePolicy policy;

  /// Primary gesture kind.
  final SieGestureKind? primaryKind;

  /// Primary phase.
  final SieGesturePhase primaryPhase;

  /// Last error.
  final SieFailure? lastError;

  /// Last event label.
  final String? lastEvent;

  /// Policy id.
  SieGesturePolicyId get policyId => policy.id;

  /// Copy with overrides.
  SieGestureEngineStatus copyWith({
    SieGestureEngineHealth? health,
    bool? initialized,
    bool? running,
    SieGestureActivity? activity,
    SieGesturePolicy? policy,
    SieGestureKind? primaryKind,
    bool clearPrimary = false,
    SieGesturePhase? primaryPhase,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieGestureEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      activity: activity ?? this.activity,
      policy: policy ?? this.policy,
      primaryKind: clearPrimary ? null : (primaryKind ?? this.primaryKind),
      primaryPhase: primaryPhase ?? this.primaryPhase,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics.
final class SieGestureEngineMetrics {
  /// Creates metrics.
  const SieGestureEngineMetrics({
    this.framesProcessed = 0,
    this.eventsEmitted = 0,
    this.commitsRecognized = 0,
    this.cancelsRecognized = 0,
    this.conflictsResolved = 0,
    this.suppressedWhileRecovering = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
    this.averageRecognitionConfidence = 0,
  });

  /// Frames processed.
  final int framesProcessed;

  /// Events emitted.
  final int eventsEmitted;

  /// Pinch commits.
  final int commitsRecognized;

  /// Fist cancels.
  final int cancelsRecognized;

  /// Conflict resolutions.
  final int conflictsResolved;

  /// Frames where commits suppressed (Recovering / Lost).
  final int suppressedWhileRecovering;

  /// Mean processing ms.
  final double averageProcessingMs;

  /// Last processing ms.
  final double lastProcessingMs;

  /// Mean event confidence.
  final double averageRecognitionConfidence;

  /// Copy with overrides.
  SieGestureEngineMetrics copyWith({
    int? framesProcessed,
    int? eventsEmitted,
    int? commitsRecognized,
    int? cancelsRecognized,
    int? conflictsResolved,
    int? suppressedWhileRecovering,
    double? averageProcessingMs,
    double? lastProcessingMs,
    double? averageRecognitionConfidence,
  }) {
    return SieGestureEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      eventsEmitted: eventsEmitted ?? this.eventsEmitted,
      commitsRecognized: commitsRecognized ?? this.commitsRecognized,
      cancelsRecognized: cancelsRecognized ?? this.cancelsRecognized,
      conflictsResolved: conflictsResolved ?? this.conflictsResolved,
      suppressedWhileRecovering:
          suppressedWhileRecovering ?? this.suppressedWhileRecovering,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
      averageRecognitionConfidence:
          averageRecognitionConfidence ?? this.averageRecognitionConfidence,
    );
  }
}
