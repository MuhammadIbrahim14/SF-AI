import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';

/// Low-frequency intent engine status (Riverpod-safe).
final class SieIntentEngineStatus {
  /// Creates status.
  const SieIntentEngineStatus({
    required this.health,
    required this.initialized,
    required this.running,
    required this.mode,
    required this.policy,
    required this.securityLevel,
    required this.routeKind,
    this.primaryKind,
    this.lastError,
    this.lastEvent,
  });

  /// Idle.
  factory SieIntentEngineStatus.idle() => const SieIntentEngineStatus(
        health: SieIntentEngineHealth.idle,
        initialized: false,
        running: false,
        mode: SieInteractionMode.idle,
        policy: SieIntentPolicy.standard,
        securityLevel: SieSecurityLevel.l1Standard,
        routeKind: SieRouteCapabilityKind.dashboard,
      );

  /// Health.
  final SieIntentEngineHealth health;

  /// Initialized.
  final bool initialized;

  /// Running.
  final bool running;

  /// Interaction mode.
  final SieInteractionMode mode;

  /// Policy.
  final SieIntentPolicy policy;

  /// Security level.
  final SieSecurityLevel securityLevel;

  /// Route kind.
  final SieRouteCapabilityKind routeKind;

  /// Primary intent.
  final SieIntentKind? primaryKind;

  /// Last error.
  final SieFailure? lastError;

  /// Last event.
  final String? lastEvent;

  /// Policy id.
  SieIntentPolicyId get policyId => policy.id;

  /// Copy.
  SieIntentEngineStatus copyWith({
    SieIntentEngineHealth? health,
    bool? initialized,
    bool? running,
    SieInteractionMode? mode,
    SieIntentPolicy? policy,
    SieSecurityLevel? securityLevel,
    SieRouteCapabilityKind? routeKind,
    SieIntentKind? primaryKind,
    bool clearPrimary = false,
    SieFailure? lastError,
    bool clearError = false,
    String? lastEvent,
  }) {
    return SieIntentEngineStatus(
      health: health ?? this.health,
      initialized: initialized ?? this.initialized,
      running: running ?? this.running,
      mode: mode ?? this.mode,
      policy: policy ?? this.policy,
      securityLevel: securityLevel ?? this.securityLevel,
      routeKind: routeKind ?? this.routeKind,
      primaryKind: clearPrimary ? null : (primaryKind ?? this.primaryKind),
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// Engineering metrics.
final class SieIntentEngineMetrics {
  /// Creates metrics.
  const SieIntentEngineMetrics({
    this.framesProcessed = 0,
    this.intentsGenerated = 0,
    this.intentsSuppressed = 0,
    this.securityBlocks = 0,
    this.routeBlocks = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
  });

  /// Frames.
  final int framesProcessed;

  /// Actionable intents.
  final int intentsGenerated;

  /// Suppressed.
  final int intentsSuppressed;

  /// Security blocks.
  final int securityBlocks;

  /// Route blocks.
  final int routeBlocks;

  /// Avg ms.
  final double averageProcessingMs;

  /// Last ms.
  final double lastProcessingMs;

  /// Copy.
  SieIntentEngineMetrics copyWith({
    int? framesProcessed,
    int? intentsGenerated,
    int? intentsSuppressed,
    int? securityBlocks,
    int? routeBlocks,
    double? averageProcessingMs,
    double? lastProcessingMs,
  }) {
    return SieIntentEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      intentsGenerated: intentsGenerated ?? this.intentsGenerated,
      intentsSuppressed: intentsSuppressed ?? this.intentsSuppressed,
      securityBlocks: securityBlocks ?? this.securityBlocks,
      routeBlocks: routeBlocks ?? this.routeBlocks,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
    );
  }
}
