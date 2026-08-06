import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Low-frequency arbitration status (Riverpod-safe).
final class SieArbitrationEngineStatus {
  /// Creates status.
  const SieArbitrationEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.owner,
    required this.policyId,
    this.lastError,
    this.lastEvent,
  });

  /// Idle.
  factory SieArbitrationEngineStatus.idle() => const SieArbitrationEngineStatus(
        health: SieArbitrationEngineHealth.idle,
        initialized: false,
        running: false,
        owner: SieInputSource.none,
        policyId: SieArbitrationPolicyId.lastActiveWins,
      );

  /// Health.
  final SieArbitrationEngineHealth health;

  /// Initialized.
  final bool initialized;

  /// Running.
  final bool running;

  /// Active owner.
  final SieInputSource owner;

  /// Policy.
  final SieArbitrationPolicyId policyId;

  /// Last error.
  final SieFailure? lastError;

  /// Last event.
  final String? lastEvent;

  /// Copy.
  SieArbitrationEngineStatus copyWith({
    SieArbitrationEngineHealth? health,
    bool? initialized,
    bool? running,
    SieInputSource? owner,
    SieArbitrationPolicyId? policyId,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieArbitrationEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      owner: owner ?? this.owner,
      policyId: policyId ?? this.policyId,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics.
final class SieArbitrationEngineMetrics {
  /// Creates metrics.
  const SieArbitrationEngineMetrics({
    this.framesProcessed = 0,
    this.ownershipTransitions = 0,
    this.conflictsResolved = 0,
    this.lostOwnershipEvents = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
  });

  /// Frames.
  final int framesProcessed;

  /// Transitions.
  final int ownershipTransitions;

  /// Conflicts.
  final int conflictsResolved;

  /// Lost ownership.
  final int lostOwnershipEvents;

  /// Avg ms.
  final double averageProcessingMs;

  /// Last ms.
  final double lastProcessingMs;

  /// Copy.
  SieArbitrationEngineMetrics copyWith({
    int? framesProcessed,
    int? ownershipTransitions,
    int? conflictsResolved,
    int? lostOwnershipEvents,
    double? averageProcessingMs,
    double? lastProcessingMs,
  }) {
    return SieArbitrationEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      ownershipTransitions:
          ownershipTransitions ?? this.ownershipTransitions,
      conflictsResolved: conflictsResolved ?? this.conflictsResolved,
      lostOwnershipEvents: lostOwnershipEvents ?? this.lostOwnershipEvents,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
    );
  }
}
