import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_feature_registry.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';

/// Immutable integration state (host-safe).
final class SieIntegrationState {
  /// Creates state.
  const SieIntegrationState({
    required this.timestamp,
    required this.phase,
    required this.health,
    required this.lifecycle,
    required this.routePolicy,
    required this.securityLevel,
    required this.routeKind,
    required this.sieEnabled,
    required this.features,
    required this.accessibility,
    required this.availability,
    this.inputOwner = SieInputSource.none,
    this.degradation = SieDegradationReason.none,
    this.permissionGranted = true,
    this.module = SieAppModuleId.custom,
    this.metadata = const {},
  });

  /// Idle factory.
  factory SieIntegrationState.idle(DateTime timestamp) => SieIntegrationState(
        timestamp: timestamp,
        phase: SieIntegrationPhase.unregistered,
        health: SieIntegrationHealth.idle,
        lifecycle: SieAppLifecycleState.cold,
        routePolicy: SieSkillForgeRouteCatalog.landing,
        securityLevel: SieSecurityLevel.l0Public,
        routeKind: SieRouteCapabilityKind.marketing,
        sieEnabled: false,
        features: const {},
        accessibility: SieAccessibilityState.defaults,
        availability: SieInteractionAvailability.traditionalOnly,
      );

  /// Timestamp.
  final DateTime timestamp;

  /// Phase.
  final SieIntegrationPhase phase;

  /// Health.
  final SieIntegrationHealth health;

  /// App lifecycle.
  final SieAppLifecycleState lifecycle;

  /// Active route policy.
  final SieRoutePolicy routePolicy;

  /// Effective security.
  final SieSecurityLevel securityLevel;

  /// Route capability kind.
  final SieRouteCapabilityKind routeKind;

  /// Host + policy SIE enablement.
  final bool sieEnabled;

  /// Feature map snapshot.
  final Map<SieIntegrationFeatureId, bool> features;

  /// Accessibility.
  final SieAccessibilityState accessibility;

  /// Platform / camera availability.
  final SieInteractionAvailability availability;

  /// Current input owner (from arbitration when known).
  final SieInputSource inputOwner;

  /// Degradation reason.
  final SieDegradationReason degradation;

  /// Camera permission (summary).
  final bool permissionGranted;

  /// Active module.
  final SieAppModuleId module;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Whether traditional input remains available (always true for fail-open).
  bool get traditionalAvailable => true;

  /// Copy.
  SieIntegrationState copyWith({
    DateTime? timestamp,
    SieIntegrationPhase? phase,
    SieIntegrationHealth? health,
    SieAppLifecycleState? lifecycle,
    SieRoutePolicy? routePolicy,
    SieSecurityLevel? securityLevel,
    SieRouteCapabilityKind? routeKind,
    bool? sieEnabled,
    Map<SieIntegrationFeatureId, bool>? features,
    SieAccessibilityState? accessibility,
    SieInteractionAvailability? availability,
    SieInputSource? inputOwner,
    SieDegradationReason? degradation,
    bool? permissionGranted,
    SieAppModuleId? module,
    Map<String, Object?>? metadata,
  }) {
    return SieIntegrationState(
      timestamp: timestamp ?? this.timestamp,
      phase: phase ?? this.phase,
      health: health ?? this.health,
      lifecycle: lifecycle ?? this.lifecycle,
      routePolicy: routePolicy ?? this.routePolicy,
      securityLevel: securityLevel ?? this.securityLevel,
      routeKind: routeKind ?? this.routeKind,
      sieEnabled: sieEnabled ?? this.sieEnabled,
      features: features ?? this.features,
      accessibility: accessibility ?? this.accessibility,
      availability: availability ?? this.availability,
      inputOwner: inputOwner ?? this.inputOwner,
      degradation: degradation ?? this.degradation,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      module: module ?? this.module,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Build features from registry.
  static Map<SieIntegrationFeatureId, bool> featuresFrom(
    SieFeatureRegistry registry,
  ) =>
      Map.unmodifiable(registry.asMap());
}

/// Low-frequency status (Riverpod-safe).
final class SieIntegrationStatus {
  /// Creates status.
  const SieIntegrationStatus({
    required this.phase,
    required this.health,
    required this.sieEnabled,
    required this.routeId,
    required this.routeMode,
    required this.securityLevel,
    required this.routeKind,
    required this.inputOwner,
    required this.degradation,
    this.lastEvent,
  });

  /// Idle.
  factory SieIntegrationStatus.idle() => const SieIntegrationStatus(
        phase: SieIntegrationPhase.unregistered,
        health: SieIntegrationHealth.idle,
        sieEnabled: false,
        routeId: 'landing',
        routeMode: SieRouteSieMode.enabled,
        securityLevel: SieSecurityLevel.l0Public,
        routeKind: SieRouteCapabilityKind.marketing,
        inputOwner: SieInputSource.none,
        degradation: SieDegradationReason.none,
      );

  /// Phase.
  final SieIntegrationPhase phase;

  /// Health.
  final SieIntegrationHealth health;

  /// SIE enabled.
  final bool sieEnabled;

  /// Active route id.
  final String routeId;

  /// Route mode.
  final SieRouteSieMode routeMode;

  /// Security.
  final SieSecurityLevel securityLevel;

  /// Route kind.
  final SieRouteCapabilityKind routeKind;

  /// Owner.
  final SieInputSource inputOwner;

  /// Degradation.
  final SieDegradationReason degradation;

  /// Last event name.
  final String? lastEvent;

  /// Copy.
  SieIntegrationStatus copyWith({
    SieIntegrationPhase? phase,
    SieIntegrationHealth? health,
    bool? sieEnabled,
    String? routeId,
    SieRouteSieMode? routeMode,
    SieSecurityLevel? securityLevel,
    SieRouteCapabilityKind? routeKind,
    SieInputSource? inputOwner,
    SieDegradationReason? degradation,
    String? lastEvent,
  }) {
    return SieIntegrationStatus(
      phase: phase ?? this.phase,
      health: health ?? this.health,
      sieEnabled: sieEnabled ?? this.sieEnabled,
      routeId: routeId ?? this.routeId,
      routeMode: routeMode ?? this.routeMode,
      securityLevel: securityLevel ?? this.securityLevel,
      routeKind: routeKind ?? this.routeKind,
      inputOwner: inputOwner ?? this.inputOwner,
      degradation: degradation ?? this.degradation,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }

  /// From state.
  factory SieIntegrationStatus.fromState(
    SieIntegrationState state, {
    String? lastEvent,
  }) {
    return SieIntegrationStatus(
      phase: state.phase,
      health: state.health,
      sieEnabled: state.sieEnabled,
      routeId: state.routePolicy.routeId,
      routeMode: state.routePolicy.mode,
      securityLevel: state.securityLevel,
      routeKind: state.routeKind,
      inputOwner: state.inputOwner,
      degradation: state.degradation,
      lastEvent: lastEvent,
    );
  }
}
