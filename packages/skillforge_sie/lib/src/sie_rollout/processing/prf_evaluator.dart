import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_device_capability.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_snapshot.dart';

/// Evaluation input (immutable).
final class PrfEvaluationContext {
  /// Creates context.
  const PrfEvaluationContext({
    required this.platform,
    required this.segment,
    required this.routeId,
    required this.device,
    required this.config,
    required this.telemetry,
    required this.userKey,
    this.forceRollback = false,
  });

  /// Platform.
  final SiePlatformKind platform;

  /// Segment.
  final PrfUserSegment segment;

  /// Route.
  final String routeId;

  /// Device.
  final PrfDeviceCapability device;

  /// Config.
  final PrfConfig config;

  /// Telemetry.
  final PrfTelemetrySample telemetry;

  /// Stable user key for canary / A/B hashing.
  final String userKey;

  /// Force rollback path.
  final bool forceRollback;
}

/// Deterministic pure evaluator (no I/O).
abstract final class PrfEvaluator {
  /// Evaluate rollout decision → immutable snapshot.
  static PrfRolloutSnapshot evaluate(
    PrfEvaluationContext ctx, {
    required DateTime timestamp,
  }) {
    final config = ctx.config;
    final flags = config.flags;
    final killActive = config.killSwitch.isActive(segment: ctx.segment);

    if (killActive) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.killSwitch,
        rejection: PrfRejectionReason.killSwitch,
        kill: true,
      );
    }

    if (ctx.forceRollback) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.rollback,
        rejection: PrfRejectionReason.rollback,
        rolledBack: true,
      );
    }

    if (!flags.enableSie) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.disable,
        rejection: PrfRejectionReason.featureFlagDisabled,
      );
    }

    if (!config.platforms.allows(ctx.platform)) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.disable,
        rejection: PrfRejectionReason.platformRejected,
      );
    }

    if (!ctx.device.isEligible) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.disable,
        rejection: PrfRejectionReason.deviceRejected,
      );
    }

    if (!config.segments.allows(ctx.segment)) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.disable,
        rejection: PrfRejectionReason.segmentRejected,
      );
    }

    if (!PrfRouteCatalog.allowsSie(ctx.routeId)) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.disable,
        rejection: PrfRejectionReason.routeRejected,
      );
    }

    final canary = config.canaryPhase;
    if (canary != PrfCanaryPhase.p100 && canary != PrfCanaryPhase.off) {
      if (!PrfCanaryAssigner.inCohort(ctx.userKey, canary.percent)) {
        return _deny(
          ctx,
          timestamp,
          decision: PrfRolloutDecision.hold,
          rejection: PrfRejectionReason.canaryExcluded,
        );
      }
    } else if (canary == PrfCanaryPhase.off) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.disable,
        rejection: PrfRejectionReason.canaryExcluded,
      );
    }

    if (!PrfTelemetryGate.isHealthy(ctx.telemetry, config.thresholds)) {
      return _deny(
        ctx,
        timestamp,
        decision: PrfRolloutDecision.rollback,
        rejection: PrfRejectionReason.telemetryUnhealthy,
        rolledBack: true,
      );
    }

    final cohort = config.experimentId == null
        ? PrfExperimentCohort.none
        : PrfAbAssigner.assign(ctx.userKey, config.experimentId!);

    return PrfRolloutSnapshot(
      timestamp: timestamp,
      platform: ctx.platform,
      segment: ctx.segment,
      routeId: ctx.routeId,
      device: ctx.device,
      flags: flags,
      telemetry: ctx.telemetry,
      decision: PrfRolloutDecision.enable,
      rejection: PrfRejectionReason.none,
      canaryPhase: canary,
      cohort: cohort,
      killSwitchActive: false,
      rolledBack: false,
      sieEnabled: true,
      configSource: config.source,
      metadata: {
        if (config.experimentId != null) 'experimentId': config.experimentId,
        'platformMaturity': config.platforms.maturityOf(ctx.platform).name,
      },
    );
  }

  static PrfRolloutSnapshot _deny(
    PrfEvaluationContext ctx,
    DateTime timestamp, {
    required PrfRolloutDecision decision,
    required PrfRejectionReason rejection,
    bool kill = false,
    bool rolledBack = false,
  }) {
    return PrfRolloutSnapshot.disabled(
      timestamp: timestamp,
      platform: ctx.platform,
      segment: ctx.segment,
      routeId: ctx.routeId,
      device: ctx.device,
      flags: ctx.config.flags,
      rejection: rejection,
      decision: decision,
      canaryPhase: ctx.config.canaryPhase,
      cohort: ctx.config.experimentId == null
          ? PrfExperimentCohort.none
          : PrfAbAssigner.assign(ctx.userKey, ctx.config.experimentId!),
      killSwitchActive: kill,
      rolledBack: rolledBack,
      configSource: ctx.config.source,
      telemetry: ctx.telemetry,
    );
  }
}

/// Deterministic canary bucketing (stable hash).
abstract final class PrfCanaryAssigner {
  /// Whether [userKey] falls in [percent]% cohort.
  static bool inCohort(String userKey, int percent) {
    if (percent <= 0) return false;
    if (percent >= 100) return true;
    final bucket = _bucket(userKey, salt: 'canary');
    return bucket < percent;
  }
}

/// Deterministic A/B assignment.
abstract final class PrfAbAssigner {
  /// Assign cohort for experiment.
  static PrfExperimentCohort assign(String userKey, String experimentId) {
    final bucket = _bucket('$experimentId::$userKey', salt: 'ab');
    return bucket < 50
        ? PrfExperimentCohort.groupA
        : PrfExperimentCohort.groupB;
  }
}

/// Telemetry threshold gate.
abstract final class PrfTelemetryGate {
  /// Whether sample meets thresholds.
  static bool isHealthy(
    PrfTelemetrySample t,
    PrfPerformanceThresholds th,
  ) {
    if (!t.thermalOk) return false;
    if (t.averageFps < th.minAverageFps) return false;
    if (t.cameraFps > 0 && t.cameraFps < th.minCameraFps) return false;
    if (t.trackingStability < th.minTrackingStability) return false;
    if (t.gestureConfidence < th.minGestureConfidence) return false;
    if (t.cursorLatencyMs > th.maxCursorLatencyMs) return false;
    if (t.processingLatencyMs > th.maxProcessingLatencyMs) return false;
    if (t.cpuUsage > th.maxCpuUsage) return false;
    if (t.memoryMb > th.maxMemoryMb) return false;
    if (t.lostTrackingRate > th.maxLostTrackingRate) return false;
    if (t.falseClickRate > th.maxFalseClickRate) return false;
    if (t.crashRate > th.maxCrashRate) return false;
    return true;
  }

  /// Whether sample should trigger automatic rollback while enabled.
  static bool shouldRollback(
    PrfTelemetrySample t,
    PrfPerformanceThresholds th,
  ) =>
      !isHealthy(t, th);
}

/// Config precedence: remote > runtime > build > local.
abstract final class PrfConfigResolver {
  /// Resolve winning config.
  static PrfConfig resolve({
    PrfConfig local = const PrfConfig(),
    PrfConfig? buildTime,
    PrfConfig? runtime,
    PrfConfig? remote,
  }) {
    var result = local.copyWith(source: PrfConfigSource.localDefaults);
    if (buildTime != null) {
      result = _overlay(result, buildTime, PrfConfigSource.buildTime);
    }
    if (runtime != null) {
      result = _overlay(result, runtime, PrfConfigSource.runtime);
    }
    if (remote != null) {
      result = _overlay(result, remote, PrfConfigSource.remote);
    }
    return result;
  }

  static PrfConfig _overlay(
    PrfConfig base,
    PrfConfig overlay,
    PrfConfigSource source,
  ) {
    return PrfConfig(
      flags: base.flags.merge(overlay.flags),
      platforms: overlay.platforms,
      segments: overlay.segments,
      thresholds: overlay.thresholds,
      killSwitch: overlay.killSwitch,
      canaryPhase: overlay.canaryPhase,
      experimentId: overlay.experimentId ?? base.experimentId,
      source: source,
    );
  }
}

int _bucket(String key, {required String salt}) {
  // FNV-1a 32-bit → 0..99
  var hash = 0x811c9dc5;
  final s = '$salt::$key';
  for (var i = 0; i < s.length; i++) {
    hash ^= s.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash % 100;
}
