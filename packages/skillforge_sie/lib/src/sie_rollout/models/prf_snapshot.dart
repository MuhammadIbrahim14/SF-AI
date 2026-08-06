import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_device_capability.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';

/// Immutable authoritative rollout snapshot.
final class PrfRolloutSnapshot {
  /// Creates snapshot.
  const PrfRolloutSnapshot({
    required this.timestamp,
    required this.platform,
    required this.segment,
    required this.routeId,
    required this.device,
    required this.flags,
    required this.telemetry,
    required this.decision,
    required this.rejection,
    required this.canaryPhase,
    required this.cohort,
    required this.killSwitchActive,
    required this.rolledBack,
    required this.sieEnabled,
    required this.configSource,
    this.metadata = const {},
  });

  /// Idle / disabled.
  factory PrfRolloutSnapshot.disabled({
    required DateTime timestamp,
    required SiePlatformKind platform,
    required PrfUserSegment segment,
    required String routeId,
    required PrfDeviceCapability device,
    required PrfFeatureFlags flags,
    required PrfRejectionReason rejection,
    PrfRolloutDecision decision = PrfRolloutDecision.disable,
    PrfCanaryPhase canaryPhase = PrfCanaryPhase.off,
    PrfExperimentCohort cohort = PrfExperimentCohort.none,
    bool killSwitchActive = false,
    bool rolledBack = false,
    PrfConfigSource configSource = PrfConfigSource.localDefaults,
    PrfTelemetrySample? telemetry,
  }) {
    return PrfRolloutSnapshot(
      timestamp: timestamp,
      platform: platform,
      segment: segment,
      routeId: routeId,
      device: device,
      flags: flags,
      telemetry: telemetry ?? PrfTelemetrySample.healthy(timestamp),
      decision: decision,
      rejection: rejection,
      canaryPhase: canaryPhase,
      cohort: cohort,
      killSwitchActive: killSwitchActive,
      rolledBack: rolledBack,
      sieEnabled: false,
      configSource: configSource,
    );
  }

  /// Timestamp.
  final DateTime timestamp;

  /// Platform.
  final SiePlatformKind platform;

  /// Segment.
  final PrfUserSegment segment;

  /// Route id.
  final String routeId;

  /// Device capability.
  final PrfDeviceCapability device;

  /// Active flags.
  final PrfFeatureFlags flags;

  /// Telemetry summary.
  final PrfTelemetrySample telemetry;

  /// Decision.
  final PrfRolloutDecision decision;

  /// Rejection reason.
  final PrfRejectionReason rejection;

  /// Canary phase.
  final PrfCanaryPhase canaryPhase;

  /// A/B cohort.
  final PrfExperimentCohort cohort;

  /// Kill switch.
  final bool killSwitchActive;

  /// Rollback flag.
  final bool rolledBack;

  /// Effective SIE enablement.
  final bool sieEnabled;

  /// Config source.
  final PrfConfigSource configSource;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Diagnostics map (engineering).
  Map<String, Object?> toDiagnostics() => {
        'timestamp': timestamp.toIso8601String(),
        'platform': platform.name,
        'segment': segment.name,
        'routeId': routeId,
        'deviceEligible': device.isEligible,
        'flags': flags.asMap(),
        'telemetry': telemetry.toSummary(),
        'decision': decision.name,
        'rejection': rejection.name,
        'canaryPhase': canaryPhase.name,
        'canaryPercent': canaryPhase.percent,
        'cohort': cohort.name,
        'killSwitchActive': killSwitchActive,
        'rolledBack': rolledBack,
        'sieEnabled': sieEnabled,
        'configSource': configSource.name,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// Low-frequency Riverpod-safe status.
final class PrfRolloutStatus {
  /// Creates status.
  const PrfRolloutStatus({
    required this.health,
    required this.sieEnabled,
    required this.canaryPhase,
    required this.platform,
    required this.platformAllowed,
    required this.killSwitchActive,
    required this.flags,
    this.lastDecision = PrfRolloutDecision.disable,
    this.lastEvent,
  });

  /// Idle.
  factory PrfRolloutStatus.idle() => const PrfRolloutStatus(
        health: PrfHealth.idle,
        sieEnabled: false,
        canaryPhase: PrfCanaryPhase.off,
        platform: SiePlatformKind.unsupported,
        platformAllowed: false,
        killSwitchActive: false,
        flags: PrfFeatureFlags.disabled,
      );

  /// Health.
  final PrfHealth health;

  /// Enabled.
  final bool sieEnabled;

  /// Canary.
  final PrfCanaryPhase canaryPhase;

  /// Platform.
  final SiePlatformKind platform;

  /// Platform allowed.
  final bool platformAllowed;

  /// Kill switch.
  final bool killSwitchActive;

  /// Flags.
  final PrfFeatureFlags flags;

  /// Last decision.
  final PrfRolloutDecision lastDecision;

  /// Last event.
  final String? lastEvent;

  /// From snapshot.
  factory PrfRolloutStatus.fromSnapshot(
    PrfRolloutSnapshot snap, {
    required PrfHealth health,
    String? lastEvent,
  }) {
    return PrfRolloutStatus(
      health: health,
      sieEnabled: snap.sieEnabled,
      canaryPhase: snap.canaryPhase,
      platform: snap.platform,
      platformAllowed: snap.rejection != PrfRejectionReason.platformRejected,
      killSwitchActive: snap.killSwitchActive,
      flags: snap.flags,
      lastDecision: snap.decision,
      lastEvent: lastEvent,
    );
  }
}
