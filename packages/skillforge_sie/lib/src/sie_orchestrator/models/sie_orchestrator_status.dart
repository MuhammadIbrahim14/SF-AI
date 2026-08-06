import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';

/// Low-frequency orchestrator status (Riverpod-safe).
final class SieOrchestratorStatus {
  /// Creates status.
  const SieOrchestratorStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.lifecycle,
    required this.mode,
    required this.interactionEnabled,
    this.lastError,
    this.lastEvent,
  });

  /// Idle.
  factory SieOrchestratorStatus.idle() => const SieOrchestratorStatus(
        health: SieOrchestratorHealth.idle,
        initialized: false,
        running: false,
        lifecycle: SieAppLifecycleState.cold,
        mode: SieOrchestrationMode.disabled,
        interactionEnabled: false,
      );

  /// Health.
  final SieOrchestratorHealth health;

  /// Initialized.
  final bool initialized;

  /// Running.
  final bool running;

  /// Lifecycle.
  final SieAppLifecycleState lifecycle;

  /// Mode.
  final SieOrchestrationMode mode;

  /// Interaction enabled.
  final bool interactionEnabled;

  /// Last error.
  final SieFailure? lastError;

  /// Last event.
  final String? lastEvent;

  /// Copy.
  SieOrchestratorStatus copyWith({
    SieOrchestratorHealth? health,
    bool? initialized,
    bool? running,
    SieAppLifecycleState? lifecycle,
    SieOrchestrationMode? mode,
    bool? interactionEnabled,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieOrchestratorStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      lifecycle: lifecycle ?? this.lifecycle,
      mode: mode ?? this.mode,
      interactionEnabled: interactionEnabled ?? this.interactionEnabled,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics.
final class SieOrchestratorMetrics {
  /// Creates metrics.
  const SieOrchestratorMetrics({
    this.framesProcessed = 0,
    this.eventsDispatched = 0,
    this.eventsBlocked = 0,
    this.focusTransitions = 0,
    this.routeTransitions = 0,
    this.lifecycleTransitions = 0,
    this.recoveryCount = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
  });

  /// Frames.
  final int framesProcessed;

  /// Dispatched.
  final int eventsDispatched;

  /// Blocked.
  final int eventsBlocked;

  /// Focus changes.
  final int focusTransitions;

  /// Route changes.
  final int routeTransitions;

  /// Lifecycle changes.
  final int lifecycleTransitions;

  /// Recoveries.
  final int recoveryCount;

  /// Avg ms.
  final double averageProcessingMs;

  /// Last ms.
  final double lastProcessingMs;

  /// Copy.
  SieOrchestratorMetrics copyWith({
    int? framesProcessed,
    int? eventsDispatched,
    int? eventsBlocked,
    int? focusTransitions,
    int? routeTransitions,
    int? lifecycleTransitions,
    int? recoveryCount,
    double? averageProcessingMs,
    double? lastProcessingMs,
  }) {
    return SieOrchestratorMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      eventsDispatched: eventsDispatched ?? this.eventsDispatched,
      eventsBlocked: eventsBlocked ?? this.eventsBlocked,
      focusTransitions: focusTransitions ?? this.focusTransitions,
      routeTransitions: routeTransitions ?? this.routeTransitions,
      lifecycleTransitions: lifecycleTransitions ?? this.lifecycleTransitions,
      recoveryCount: recoveryCount ?? this.recoveryCount,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
    );
  }
}
