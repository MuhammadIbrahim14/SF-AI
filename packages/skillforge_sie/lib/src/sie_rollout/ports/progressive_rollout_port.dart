import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_device_capability.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_snapshot.dart';

/// Progressive Rollout Framework port — sole authority for SIE enablement.
abstract interface class ProgressiveRolloutPort {
  /// Low-frequency status (Riverpod-safe).
  Stream<PrfRolloutStatus> get status;

  /// Immutable snapshots on significant decisions (internal stream).
  Stream<PrfRolloutSnapshot> get snapshots;

  /// Current status.
  PrfRolloutStatus get currentStatus;

  /// Latest snapshot.
  PrfRolloutSnapshot get latestSnapshot;

  /// Effective config.
  PrfConfig get config;

  /// Whether SIE is currently enabled by PRF.
  bool get sieEnabled;

  /// Initialize with local/build defaults and optional overrides.
  Future<void> initialize({
    required SiePlatformKind platform,
    required PrfUserSegment segment,
    required String userKey,
    String routeId = 'landing',
    PrfConfig? buildTime,
    PrfConfig? runtime,
    PrfDeviceCapability? deviceOverride,
  });

  /// Re-resolve config (fetches remote when available).
  Future<void> refreshConfiguration();

  /// Apply runtime config overlay.
  Future<void> setRuntimeConfig(PrfConfig runtime);

  /// Set feature flag independently.
  Future<void> setFeatureFlag(PrfFeatureFlagId id, {required bool enabled});

  /// Activate route for rollout evaluation.
  Future<PrfRolloutSnapshot> activateRoute(String routeId);

  /// Set user segment.
  Future<void> setSegment(PrfUserSegment segment);

  /// Ingest telemetry sample (may trigger rollback).
  Future<PrfRolloutSnapshot> ingestTelemetry(PrfTelemetrySample sample);

  /// Local kill switch.
  Future<void> activateKillSwitch({bool active = true});

  /// Remote kill (future wiring).
  Future<void> setRemoteKillSwitch({required bool active});

  /// Dev / QA overrides on kill switch.
  Future<void> setKillSwitchOverrides({
    bool? developmentOverride,
    bool? qaOverride,
  });

  /// Promote canary when telemetry healthy.
  Future<PrfCanaryPhase> promoteCanary();

  /// Halt canary (set off / rollback phase).
  Future<void> haltCanary();

  /// Force rollback to traditional interaction.
  Future<PrfRolloutSnapshot> rollback({String? reason});

  /// Re-evaluate and apply decision to Integration Framework.
  Future<PrfRolloutSnapshot> evaluate();

  /// Diagnostics for SIDF.
  Map<String, Object?> diagnosticsReport();

  /// Dispose.
  Future<void> dispose();
}
