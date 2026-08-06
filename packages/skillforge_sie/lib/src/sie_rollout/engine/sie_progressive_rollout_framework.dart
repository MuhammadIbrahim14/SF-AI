import 'dart:async';

import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_integration/ports/sie_integration_port.dart';
import 'package:skillforge_sie/src/sie_rollout/logging/prf_logger.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_device_capability.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_snapshot.dart';
import 'package:skillforge_sie/src/sie_rollout/ports/prf_remote_config_port.dart';
import 'package:skillforge_sie/src/sie_rollout/ports/progressive_rollout_port.dart';
import 'package:skillforge_sie/src/sie_rollout/processing/prf_evaluator.dart';

/// Production Progressive Rollout Framework — sole SIE enablement authority.
final class SieProgressiveRolloutFramework implements ProgressiveRolloutPort {
  /// Creates framework.
  SieProgressiveRolloutFramework({
    SieIntegrationPort? integration,
    SidfDiagnosticsPort? diagnostics,
    PrfRemoteConfigPort remoteConfig = const NopPrfRemoteConfig(),
    PrfDeviceCapabilityProbePort deviceProbe =
        const DefaultPrfDeviceCapabilityProbe(),
    PrfConfig localDefaults = const PrfConfig(),
    PrfLogger logger = const DeveloperPrfLogger(),
  })  : _integration = integration,
        _diagnostics = diagnostics,
        _remoteConfig = remoteConfig,
        _deviceProbe = deviceProbe,
        _localDefaults = localDefaults,
        _logger = logger;

  final SieIntegrationPort? _integration;
  final SidfDiagnosticsPort? _diagnostics;
  final PrfRemoteConfigPort _remoteConfig;
  final PrfDeviceCapabilityProbePort _deviceProbe;
  final PrfConfig _localDefaults;
  final PrfLogger _logger;

  final StreamController<PrfRolloutStatus> _statusController =
      StreamController<PrfRolloutStatus>.broadcast();
  final StreamController<PrfRolloutSnapshot> _snapshotController =
      StreamController<PrfRolloutSnapshot>.broadcast();

  PrfConfig? _buildTime;
  PrfConfig? _runtime;
  PrfConfig? _remote;
  PrfConfig _resolved = const PrfConfig();

  SiePlatformKind _platform = SiePlatformKind.unsupported;
  PrfUserSegment _segment = PrfUserSegment.publicUsers;
  String _userKey = 'anonymous';
  String _routeId = 'landing';
  PrfDeviceCapability _device =
      PrfDeviceCapability.insufficient(SiePlatformKind.unsupported);
  PrfTelemetrySample _telemetry = PrfTelemetrySample.healthy();
  bool _forceRollback = false;
  bool _initialized = false;
  bool _disposed = false;

  PrfRolloutSnapshot _latest = PrfRolloutSnapshot.disabled(
    timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    platform: SiePlatformKind.unsupported,
    segment: PrfUserSegment.publicUsers,
    routeId: 'landing',
    device: PrfDeviceCapability.insufficient(SiePlatformKind.unsupported),
    flags: PrfFeatureFlags.disabled,
    rejection: PrfRejectionReason.none,
  );
  PrfRolloutStatus _status = PrfRolloutStatus.idle();
  Future<void> _queue = Future<void>.value();

  @override
  Stream<PrfRolloutStatus> get status => _statusController.stream;

  @override
  Stream<PrfRolloutSnapshot> get snapshots => _snapshotController.stream;

  @override
  PrfRolloutStatus get currentStatus => _status;

  @override
  PrfRolloutSnapshot get latestSnapshot => _latest;

  @override
  PrfConfig get config => _resolved;

  @override
  bool get sieEnabled => _latest.sieEnabled;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _publish(PrfRolloutSnapshot snap, {required String event}) {
    _latest = snap;
    final health = snap.killSwitchActive
        ? PrfHealth.emergency
        : (snap.rolledBack ||
                snap.rejection == PrfRejectionReason.telemetryUnhealthy
            ? PrfHealth.degraded
            : (snap.sieEnabled ? PrfHealth.healthy : PrfHealth.degraded));
    _status = PrfRolloutStatus.fromSnapshot(
      snap,
      health: _initialized ? health : PrfHealth.idle,
      lastEvent: event,
    );
    if (!_statusController.isClosed) _statusController.add(_status);
    if (!_snapshotController.isClosed) _snapshotController.add(snap);
  }

  void _resolveConfig() {
    _resolved = PrfConfigResolver.resolve(
      local: _localDefaults,
      buildTime: _buildTime,
      runtime: _runtime,
      remote: _remote,
    );
  }

  @override
  Future<void> initialize({
    required SiePlatformKind platform,
    required PrfUserSegment segment,
    required String userKey,
    String routeId = 'landing',
    PrfConfig? buildTime,
    PrfConfig? runtime,
    PrfDeviceCapability? deviceOverride,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        _platform = platform;
        _segment = segment;
        _userKey = userKey;
        _routeId = routeId;
        if (buildTime != null) _buildTime = buildTime;
        if (runtime != null) _runtime = runtime;
        _remote = await _remoteConfig.fetch();
        _resolveConfig();
        _device = deviceOverride ?? await _deviceProbe.probe(platform);
        _initialized = true;
        _telemetry = PrfTelemetrySample.healthy(DateTime.now().toUtc());
        final snap = await _evaluateAndApply(event: 'initialized');
        _logger.info('rollout_initialized', {
          'platform': platform.name,
          'segment': segment.name,
          'enabled': snap.sieEnabled,
          'source': _resolved.source.name,
        });
      });

  @override
  Future<void> refreshConfiguration() => _serialized(() async {
        _ensureReady();
        try {
          _remote = await _remoteConfig.fetch();
        } catch (e) {
          _logger.warn('telemetry_config_fetch_failed', {'error': '$e'});
        }
        _resolveConfig();
        await _evaluateAndApply(event: 'config_refreshed');
      });

  @override
  Future<void> setRuntimeConfig(PrfConfig runtime) => _serialized(() async {
        _ensureReady();
        _runtime = runtime;
        _resolveConfig();
        _logger.info('feature_flag_changed', {'source': 'runtime'});
        await _evaluateAndApply(event: 'runtime_config');
      });

  @override
  Future<void> setFeatureFlag(
    PrfFeatureFlagId id, {
    required bool enabled,
  }) =>
      _serialized(() async {
        _ensureReady();
        final base = _runtime?.flags ?? _resolved.flags;
        final next = switch (id) {
          PrfFeatureFlagId.enableSie => base.copyWith(enableSie: enabled),
          PrfFeatureFlagId.experimentalGestures =>
            base.copyWith(experimentalGestures: enabled),
          PrfFeatureFlagId.twoHandTracking =>
            base.copyWith(twoHandTracking: enabled),
          PrfFeatureFlagId.eyeTracking => base.copyWith(eyeTracking: enabled),
          PrfFeatureFlagId.voiceControl => base.copyWith(voiceControl: enabled),
          PrfFeatureFlagId.debugOverlay => base.copyWith(debugOverlay: enabled),
          PrfFeatureFlagId.accessibilityFeatures =>
            base.copyWith(accessibilityFeatures: enabled),
          PrfFeatureFlagId.betaFeatures => base.copyWith(betaFeatures: enabled),
        };
        _runtime = (_runtime ?? _resolved).copyWith(
          flags: next,
          source: PrfConfigSource.runtime,
        );
        _resolveConfig();
        _logger.info('feature_flag_changed', {
          'flag': id.name,
          'enabled': enabled,
        });
        await _evaluateAndApply(event: 'feature_flag');
      });

  @override
  Future<PrfRolloutSnapshot> activateRoute(String routeId) =>
      _serialized(() async {
        _ensureReady();
        _routeId = routeId;
        final integration = _integration;
        if (integration != null) {
          try {
            await integration.activateRoute(routeId);
          } catch (_) {
            // Route may be PRF-only alias; continue evaluation.
          }
        }
        return _evaluateAndApply(event: 'route_activated');
      });

  @override
  Future<void> setSegment(PrfUserSegment segment) => _serialized(() async {
        _ensureReady();
        _segment = segment;
        await _evaluateAndApply(event: 'segment_changed');
      });

  @override
  Future<PrfRolloutSnapshot> ingestTelemetry(PrfTelemetrySample sample) =>
      _serialized(() async {
        _ensureReady();
        _telemetry = sample;
        if (_latest.sieEnabled &&
            PrfTelemetryGate.shouldRollback(sample, _resolved.thresholds)) {
          _forceRollback = true;
          _logger.warn('rollback_executed', {
            'reason': 'telemetry',
            'fps': sample.averageFps,
            'latency': sample.cursorLatencyMs,
          });
        } else if (_forceRollback &&
            PrfTelemetryGate.isHealthy(sample, _resolved.thresholds)) {
          // Allow recovery after healthy samples.
          _forceRollback = false;
        }
        return _evaluateAndApply(event: 'telemetry');
      });

  @override
  Future<void> activateKillSwitch({bool active = true}) =>
      _serialized(() async {
        _ensureReady();
        final ks = _resolved.killSwitch.copyWith(localActive: active);
        _runtime = (_runtime ?? _resolved).copyWith(killSwitch: ks);
        _resolveConfig();
        _logger.warn('kill_switch_activated', {'active': active, 'local': true});
        await _evaluateAndApply(event: 'kill_switch');
      });

  @override
  Future<void> setRemoteKillSwitch({required bool active}) =>
      _serialized(() async {
        _ensureReady();
        final ks = _resolved.killSwitch.copyWith(remoteActive: active);
        _runtime = (_runtime ?? _resolved).copyWith(killSwitch: ks);
        _resolveConfig();
        _logger.warn('kill_switch_activated', {
          'active': active,
          'remote': true,
        });
        await _evaluateAndApply(event: 'remote_kill');
      });

  @override
  Future<void> setKillSwitchOverrides({
    bool? developmentOverride,
    bool? qaOverride,
  }) =>
      _serialized(() async {
        _ensureReady();
        final ks = _resolved.killSwitch.copyWith(
          developmentOverride: developmentOverride,
          qaOverride: qaOverride,
        );
        _runtime = (_runtime ?? _resolved).copyWith(killSwitch: ks);
        _resolveConfig();
        await _evaluateAndApply(event: 'kill_overrides');
      });

  @override
  Future<PrfCanaryPhase> promoteCanary() => _serialized(() async {
        _ensureReady();
        if (!PrfTelemetryGate.isHealthy(_telemetry, _resolved.thresholds)) {
          _logger.warn('canary_halted', {'reason': 'unhealthy_telemetry'});
          throw SieRolloutFailure(
            message: 'Cannot promote canary: telemetry unhealthy',
          );
        }
        final next = _resolved.canaryPhase.next;
        _runtime = (_runtime ?? _resolved).copyWith(canaryPhase: next);
        _resolveConfig();
        _logger.info('canary_promoted', {
          'from': _latest.canaryPhase.name,
          'to': next.name,
          'percent': next.percent,
        });
        await _evaluateAndApply(event: 'canary_promoted');
        return next;
      });

  @override
  Future<void> haltCanary() => _serialized(() async {
        _ensureReady();
        _runtime = (_runtime ?? _resolved).copyWith(
          canaryPhase: PrfCanaryPhase.off,
        );
        _resolveConfig();
        _logger.warn('canary_halted', {'phase': 'off'});
        await _evaluateAndApply(event: 'canary_halted');
      });

  @override
  Future<PrfRolloutSnapshot> rollback({String? reason}) =>
      _serialized(() async {
        _ensureReady();
        _forceRollback = true;
        _logger.warn('rollback_executed', {'reason': reason ?? 'manual'});
        return _evaluateAndApply(event: 'rollback');
      });

  @override
  Future<PrfRolloutSnapshot> evaluate() => _serialized(() async {
        _ensureReady();
        return _evaluateAndApply(event: 'evaluate');
      });

  @override
  Map<String, Object?> diagnosticsReport() => {
        ..._latest.toDiagnostics(),
        'initialized': _initialized,
        'health': _status.health.name,
        'userKeyHash': _userKey.hashCode,
      };

  @override
  Future<void> dispose() => _serialized(() async {
        if (_disposed) return;
        _disposed = true;
        _publish(
          PrfRolloutSnapshot.disabled(
            timestamp: DateTime.now().toUtc(),
            platform: _platform,
            segment: _segment,
            routeId: _routeId,
            device: _device,
            flags: PrfFeatureFlags.disabled,
            rejection: PrfRejectionReason.hostDisabled,
          ),
          event: 'disposed',
        );
        _status = PrfRolloutStatus(
          health: PrfHealth.disposed,
          sieEnabled: false,
          canaryPhase: _resolved.canaryPhase,
          platform: _platform,
          platformAllowed: false,
          killSwitchActive: false,
          flags: PrfFeatureFlags.disabled,
          lastEvent: 'disposed',
        );
        if (!_statusController.isClosed) _statusController.add(_status);
        await _statusController.close();
        await _snapshotController.close();
      });

  Future<PrfRolloutSnapshot> _evaluateAndApply({required String event}) async {
    final ctx = PrfEvaluationContext(
      platform: _platform,
      segment: _segment,
      routeId: _routeId,
      device: _device,
      config: _resolved,
      telemetry: _telemetry,
      userKey: _userKey,
      forceRollback: _forceRollback,
    );
    final snap = PrfEvaluator.evaluate(
      ctx,
      timestamp: DateTime.now().toUtc(),
    );
    _publish(snap, event: event);
    await _applyToIntegration(snap);
    _emitSidf(snap, event);
    if (snap.sieEnabled && event != 'telemetry') {
      _logger.info('rollout_enabled', {
        'route': snap.routeId,
        'canary': snap.canaryPhase.percent,
        'cohort': snap.cohort.name,
      });
    } else if (!snap.sieEnabled &&
        snap.rejection != PrfRejectionReason.none &&
        event != 'telemetry') {
      _logger.info('rollout_disabled', {
        'reason': snap.rejection.name,
        'decision': snap.decision.name,
      });
    }
    return snap;
  }

  Future<void> _applyToIntegration(PrfRolloutSnapshot snap) async {
    final integration = _integration;
    if (integration == null) return;
    try {
      if (snap.sieEnabled) {
        await integration.enable();
      } else {
        await integration.disable();
      }
    } catch (e) {
      _logger.error('integration_apply_failed', {'error': '$e'}, e);
    }
  }

  void _emitSidf(PrfRolloutSnapshot snap, String event) {
    final diag = _diagnostics;
    if (diag == null) return;
    diag.ingestRoute(snap.routeId);
    diag.recordTimeline(
      SidfTimelineEvent(
        timestamp: snap.timestamp,
        category: SidfTimelineCategory.lifecycle,
        name: 'prf_$event',
        detail: '${snap.decision.name}/${snap.rejection.name}',
        metadata: {
          'sieEnabled': snap.sieEnabled,
          'canary': snap.canaryPhase.percent,
        },
      ),
    );
    diag.ingestStage(
      SidfStageSample(
        stage: SidfPipelineStage.platform,
        health: snap.sieEnabled
            ? SidfStageHealth.healthy
            : (snap.killSwitchActive
                ? SidfStageHealth.error
                : SidfStageHealth.idle),
        timestamp: snap.timestamp,
        label: 'prf',
        metadata: {'decision': snap.decision.name},
      ),
    );
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieRolloutFailure(message: 'PRF is disposed.');
    }
  }

  void _ensureReady() {
    _ensureNotDisposed();
    if (!_initialized) {
      throw SieRolloutFailure(message: 'PRF not initialized.');
    }
  }
}
