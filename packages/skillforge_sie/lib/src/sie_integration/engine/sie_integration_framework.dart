import 'dart:async';

import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/ports/input_arbitration_engine_port.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_intent/ports/intent_engine_port.dart';
import 'package:skillforge_sie/src/sie_integration/logging/sie_integration_logger.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_feature_registry.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_state.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';
import 'package:skillforge_sie/src/sie_integration/ports/sie_integration_port.dart';
import 'package:skillforge_sie/src/sie_integration/processing/sie_integration_policy_sync.dart';
import 'package:skillforge_sie/src/sie_integration/processing/sie_route_registry.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_orchestrator_port.dart';

/// Production SIE Integration Framework — single host façade.
final class SieIntegrationFramework implements SieIntegrationPort {
  /// Creates framework.
  ///
  /// Downstream ports are optional DI — when absent, policy state still works
  /// (apps never touch Camera / Vision / Gesture directly).
  SieIntegrationFramework({
    InteractionOrchestratorPort? orchestrator,
    InputArbitrationEnginePort? arbitration,
    IntentEnginePort? intent,
    SidfDiagnosticsPort? diagnostics,
    SieIntegrationLogger logger = const DeveloperSieIntegrationLogger(),
  })  : _orchestrator = orchestrator,
        _arbitration = arbitration,
        _intent = intent,
        _diagnostics = diagnostics,
        _logger = logger;

  final InteractionOrchestratorPort? _orchestrator;
  final InputArbitrationEnginePort? _arbitration;
  final IntentEnginePort? _intent;
  final SidfDiagnosticsPort? _diagnostics;
  final SieIntegrationLogger _logger;

  final SieRouteRegistry _routes = SieRouteRegistry();
  final SieFeatureRegistry _features = SieFeatureRegistry();

  final StreamController<SieIntegrationStatus> _statusController =
      StreamController<SieIntegrationStatus>.broadcast();
  final StreamController<SieIntegrationState> _stateController =
      StreamController<SieIntegrationState>.broadcast();

  SieIntegrationState _state =
      SieIntegrationState.idle(DateTime.fromMillisecondsSinceEpoch(0));
  SieIntegrationStatus _status = SieIntegrationStatus.idle();
  bool _hostSieDesired = false;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();

  @override
  Stream<SieIntegrationStatus> get status => _statusController.stream;

  @override
  Stream<SieIntegrationState> get states => _stateController.stream;

  @override
  SieIntegrationStatus get currentStatus => _status;

  @override
  SieIntegrationState get currentState => _state;

  @override
  SieRouteRegistry get routes => _routes;

  @override
  SieFeatureRegistry get features => _features;

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

  void _publish(SieIntegrationState next, {required String event}) {
    _state = next;
    _status = SieIntegrationStatus.fromState(next, lastEvent: event);
    if (!_statusController.isClosed) _statusController.add(_status);
    if (!_stateController.isClosed) _stateController.add(next);
  }

  @override
  Future<void> register() => _serialized(() async {
        _ensureNotDisposed();
        if (_state.phase != SieIntegrationPhase.unregistered &&
            _state.phase != SieIntegrationPhase.disposed) {
          return;
        }
        _routes.registerDefaults();
        _features.registerDefaults();
        final now = DateTime.now().toUtc();
        _publish(
          _state.copyWith(
            timestamp: now,
            phase: SieIntegrationPhase.registered,
            health: SieIntegrationHealth.idle,
            routePolicy: SieSkillForgeRouteCatalog.landing,
            securityLevel: SieSkillForgeRouteCatalog.landing.securityLevel,
            routeKind: SieSkillForgeRouteCatalog.landing.capabilityKind,
            features: SieIntegrationState.featuresFrom(_features),
            module: SieAppModuleId.custom,
          ),
          event: 'registered',
        );
        _logger.info('registration', {
          'routes': _routes.length,
          'features': _features.all.length,
        });
        _noteTimeline('integration_registered', SidfTimelineCategory.lifecycle);
      });

  @override
  Future<void> initialize({
    SieInteractionAvailability? availability,
    bool permissionGranted = true,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        if (_state.phase == SieIntegrationPhase.unregistered) {
          _routes.registerDefaults();
          _features.registerDefaults();
          _publish(
            _state.copyWith(
              timestamp: DateTime.now().toUtc(),
              phase: SieIntegrationPhase.registered,
              features: SieIntegrationState.featuresFrom(_features),
            ),
            event: 'registered',
          );
        }
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            phase: SieIntegrationPhase.initializing,
          ),
          event: 'initializing',
        );
        final avail = availability ?? SieInteractionAvailability.full;
        await _applyGatesUnlocked(
          availability: avail,
          permissionGranted: permissionGranted,
          phase: SieIntegrationPhase.ready,
          event: 'initialized',
        );
        _logger.info('initialization', {
          'route': _state.routePolicy.routeId,
          'sieEnabled': _state.sieEnabled,
          'degradation': _state.degradation.name,
        });
      });

  @override
  Future<void> enable() => _serialized(() async {
        _ensureNotDisposed();
        _hostSieDesired = true;
        await _applyGatesUnlocked(event: 'sie_enabled');
        if (_state.sieEnabled) {
          _publish(
            _state.copyWith(
              timestamp: DateTime.now().toUtc(),
              phase: SieIntegrationPhase.active,
              health: SieIntegrationHealth.healthy,
            ),
            event: 'sie_active',
          );
        }
        _logger.info('feature_enablement', {'sie': _state.sieEnabled});
      });

  @override
  Future<void> disable() => _serialized(() async {
        _ensureNotDisposed();
        _hostSieDesired = false;
        await _applyGatesUnlocked(
          phase: SieIntegrationPhase.ready,
          event: 'sie_disabled',
        );
        _logger.info('feature_enablement', {'sie': false});
      });

  @override
  Future<void> pause() => _serialized(() async {
        _ensureNotDisposed();
        final orch = _orchestrator;
        if (orch != null) {
          await orch.setLifecycle(SieAppLifecycleState.paused);
        }
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            lifecycle: SieAppLifecycleState.paused,
            phase: SieIntegrationPhase.paused,
          ),
          event: 'paused',
        );
      });

  @override
  Future<void> resume() => _serialized(() async {
        _ensureNotDisposed();
        final orch = _orchestrator;
        if (orch != null) {
          await orch.setLifecycle(SieAppLifecycleState.resumed);
        }
        await _applyGatesUnlocked(
          phase: _hostSieDesired && _state.sieEnabled
              ? SieIntegrationPhase.active
              : SieIntegrationPhase.ready,
          event: 'resumed',
        );
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            lifecycle: SieAppLifecycleState.resumed,
          ),
          event: 'resumed',
        );
      });

  @override
  Future<void> shutdown() => _serialized(() async {
        _ensureNotDisposed();
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            phase: SieIntegrationPhase.shuttingDown,
          ),
          event: 'shutting_down',
        );
        _hostSieDesired = false;
        final orch = _orchestrator;
        if (orch != null) {
          await orch.setInteractionEnabled(false);
          await orch.stop();
        }
        _logger.info('shutdown');
        _noteTimeline('integration_shutdown', SidfTimelineCategory.lifecycle);
        await _disposeUnlocked();
      });

  @override
  Future<SieRoutePolicy> activateRoute(String routeId) => _serialized(() async {
        _ensureNotDisposed();
        final policy = _routes.require(routeId);
        _logger.info('route_activation', {
          'routeId': routeId,
          'mode': policy.mode.name,
          'security': policy.securityLevel.name,
        });
        await _applyGatesUnlocked(
          routePolicy: policy,
          event: 'route_activated',
        );
        _noteTimeline(
          'route_activated',
          SidfTimelineCategory.orchestration,
          detail: routeId,
        );
        return policy;
      });

  @override
  Future<void> registerRoute(SieRoutePolicy policy) => _serialized(() async {
        _ensureNotDisposed();
        _routes.register(policy);
        _logger.info('route_registered', {'routeId': policy.routeId});
      });

  @override
  Future<void> configureRoute(
    String routeId, {
    required bool sieEnabled,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        final current = _routes.require(routeId);
        if (!current.configurable) {
          throw SieIntegrationFailure(
            message: 'Route $routeId is not configurable',
          );
        }
        final next = current.copyWith(
          sieEnabled: sieEnabled,
          mode: sieEnabled
              ? SieRouteSieMode.enabled
              : SieRouteSieMode.disabled,
        );
        _routes.register(next);
        if (_state.routePolicy.routeId == routeId) {
          await _applyGatesUnlocked(
            routePolicy: next,
            event: 'route_configured',
          );
        }
        _logger.info('route_configured', {
          'routeId': routeId,
          'sieEnabled': sieEnabled,
        });
      });

  @override
  Future<void> setFeature(
    SieIntegrationFeatureId id, {
    required bool enabled,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        _features.setEnabled(id, enabled: enabled);
        var a11y = _state.accessibility;
        if (id == SieIntegrationFeatureId.reducedMotion) {
          a11y = a11y.copyWith(reducedMotion: enabled);
        } else if (id == SieIntegrationFeatureId.largeCursor) {
          a11y = a11y.copyWith(largeCursor: enabled);
        } else if (id == SieIntegrationFeatureId.dwell) {
          a11y = a11y.copyWith(dwellMode: enabled);
        } else if (id == SieIntegrationFeatureId.accessibility) {
          a11y = a11y.copyWith(
            reducedMotion: enabled || a11y.reducedMotion,
            dwellMode: enabled || a11y.dwellMode,
          );
        }
        if (id == SieIntegrationFeatureId.debugOverlay) {
          final diag = _diagnostics;
          if (diag != null) {
            await diag.setOverlayVisible(enabled);
          }
        }
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            features: SieIntegrationState.featuresFrom(_features),
            accessibility: a11y,
          ),
          event: 'feature_changed',
        );
        await _pushDownstream(accessibility: a11y);
        _logger.info('feature_enablement', {
          'feature': id.name,
          'enabled': enabled,
        });
      });

  @override
  Future<void> setLifecycle(SieAppLifecycleState lifecycle) =>
      _serialized(() async {
        _ensureNotDisposed();
        final orch = _orchestrator;
        if (orch != null) {
          await orch.setLifecycle(lifecycle);
        }
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            lifecycle: lifecycle,
          ),
          event: 'lifecycle_changed',
        );
      });

  @override
  Future<void> setAccessibility(SieAccessibilityState accessibility) =>
      _serialized(() async {
        _ensureNotDisposed();
        _features.setEnabled(
          SieIntegrationFeatureId.reducedMotion,
          enabled: accessibility.reducedMotion,
        );
        _features.setEnabled(
          SieIntegrationFeatureId.largeCursor,
          enabled: accessibility.largeCursor,
        );
        _features.setEnabled(
          SieIntegrationFeatureId.dwell,
          enabled: accessibility.dwellMode,
        );
        _features.setEnabled(
          SieIntegrationFeatureId.accessibility,
          enabled: accessibility.reducedMotion ||
              accessibility.dwellMode ||
              accessibility.highContrast ||
              accessibility.screenReader ||
              accessibility.keyboardNavigation ||
              accessibility.largeCursor,
        );
        await _applyGatesUnlocked(
          accessibility: accessibility,
          event: 'a11y_changed',
        );
      });

  @override
  Future<void> notifyCapabilities({
    SieInteractionAvailability? availability,
    bool? permissionGranted,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        await _applyGatesUnlocked(
          availability: availability,
          permissionGranted: permissionGranted,
          event: 'capabilities_changed',
        );
        if (_state.degradation != SieDegradationReason.none) {
          _logger.warn('graceful_degradation', {
            'reason': _state.degradation.name,
          });
        }
      });

  @override
  Future<void> notifyInputOwner(SieInputSource owner) => _serialized(() async {
        _ensureNotDisposed();
        _publish(
          _state.copyWith(
            timestamp: DateTime.now().toUtc(),
            inputOwner: owner,
          ),
          event: 'owner_changed',
        );
        _diagnostics?.ingestOwner(owner.name);
      });

  @override
  Map<String, Object?> diagnosticsReport() {
    return {
      'health': _state.health.name,
      'phase': _state.phase.name,
      'sieEnabled': _state.sieEnabled,
      'routeId': _state.routePolicy.routeId,
      'routeMode': _state.routePolicy.mode.name,
      'securityLevel': _state.securityLevel.name,
      'routeKind': _state.routeKind.name,
      'inputOwner': _state.inputOwner.name,
      'degradation': _state.degradation.name,
      'permissionGranted': _state.permissionGranted,
      'enabledRoutes': _routes.enabledRouteIds,
      'disabledRoutes': _routes.disabledRouteIds,
      'features': {
        for (final e in _state.features.entries) e.key.name: e.value,
      },
      'accessibility': {
        'reducedMotion': _state.accessibility.reducedMotion,
        'highContrast': _state.accessibility.highContrast,
        'largeCursor': _state.accessibility.largeCursor,
        'dwellMode': _state.accessibility.dwellMode,
        'screenReader': _state.accessibility.screenReader,
        'keyboardNavigation': _state.accessibility.keyboardNavigation,
      },
      'policyDecision': {
        'allowsSie': _state.routePolicy.allowsSie,
        'hostDesired': _hostSieDesired,
        'effective': _state.sieEnabled,
      },
    };
  }

  @override
  Future<void> dispose() => _serialized(_disposeUnlocked);

  Future<void> _disposeUnlocked() async {
    if (_disposed) return;
    _disposed = true;
    _publish(
      _state.copyWith(
        timestamp: DateTime.now().toUtc(),
        phase: SieIntegrationPhase.disposed,
        health: SieIntegrationHealth.disposed,
        sieEnabled: false,
      ),
      event: 'disposed',
    );
    await _statusController.close();
    await _stateController.close();
  }

  Future<void> _applyGatesUnlocked({
    SieRoutePolicy? routePolicy,
    SieInteractionAvailability? availability,
    bool? permissionGranted,
    SieAccessibilityState? accessibility,
    SieIntegrationPhase? phase,
    required String event,
  }) async {
    final policy = routePolicy ?? _state.routePolicy;
    final avail = availability ?? _state.availability;
    final perm = permissionGranted ?? _state.permissionGranted;
    final a11y = accessibility ?? _state.accessibility;
    final degradation = SieIntegrationPolicySync.resolveDegradation(
      hostSieEnabled: _hostSieDesired,
      policy: policy,
      availability: avail,
      permissionGranted: perm,
    );
    final sieOn = degradation == SieDegradationReason.none;

    late final SieIntegrationHealth health;
    late final SieIntegrationPhase nextPhase;
    if (phase != null) {
      nextPhase = phase;
    } else if (sieOn) {
      nextPhase = SieIntegrationPhase.active;
    } else if (_hostSieDesired &&
        degradation != SieDegradationReason.none &&
        degradation != SieDegradationReason.hostDisabled) {
      nextPhase = SieIntegrationPhase.degraded;
    } else if (_state.phase == SieIntegrationPhase.active ||
        _state.phase == SieIntegrationPhase.degraded) {
      nextPhase = SieIntegrationPhase.ready;
    } else {
      nextPhase = _state.phase;
    }

    if (nextPhase == SieIntegrationPhase.degraded) {
      health = SieIntegrationHealth.degraded;
    } else if (sieOn) {
      health = SieIntegrationHealth.healthy;
    } else if (_state.phase == SieIntegrationPhase.unregistered) {
      health = SieIntegrationHealth.idle;
    } else {
      health = SieIntegrationHealth.healthy;
    }

    _publish(
      _state.copyWith(
        timestamp: DateTime.now().toUtc(),
        phase: nextPhase,
        health: health,
        routePolicy: policy,
        securityLevel: policy.securityLevel,
        routeKind: policy.capabilityKind,
        sieEnabled: sieOn,
        features: SieIntegrationState.featuresFrom(_features),
        accessibility: a11y,
        availability: avail,
        permissionGranted: perm,
        degradation: degradation,
        module: policy.module,
      ),
      event: event,
    );

    await _pushDownstream(accessibility: a11y, sieEnabled: sieOn);
  }

  Future<void> _pushDownstream({
    SieAccessibilityState? accessibility,
    bool? sieEnabled,
  }) async {
    final a11y = accessibility ?? _state.accessibility;
    final sieOn = sieEnabled ?? _state.sieEnabled;
    final policy = _state.routePolicy;
    final paused = _state.lifecycle == SieAppLifecycleState.paused ||
        _state.lifecycle == SieAppLifecycleState.background;

    final orch = _orchestrator;
    if (orch != null) {
      await orch.setRoute(
        routeKind: policy.capabilityKind,
        securityLevel: policy.securityLevel,
      );
      await orch.setAccessibility(a11y);
      await orch.setAvailability(_state.availability);
      await orch.setInteractionEnabled(sieOn);
    }

    final arb = _arbitration;
    if (arb != null) {
      await arb.updateContext(
        SieIntegrationPolicySync.arbitrationContext(
          policy: policy,
          accessibilityMode: a11y.dwellMode ||
              a11y.screenReader ||
              a11y.keyboardNavigation,
          paused: paused,
          windowFocused: true,
        ),
      );
    }

    final intent = _intent;
    if (intent != null) {
      final ctx = SieIntegrationPolicySync.intentContext(
        policy: policy,
        accessibility: a11y,
        sieEnabled: sieOn,
        paused: paused,
        platformAllowsSie: _state.availability.platformAllowsSie,
      );
      await intent.updateContext(ctx);
    }

    final diag = _diagnostics;
    if (diag != null) {
      diag.ingestRoute(policy.routeId);
      diag.ingestAccessibility(
        'rm=${a11y.reducedMotion};lc=${a11y.largeCursor};dw=${a11y.dwellMode}',
      );
      diag.ingestOwner(_state.inputOwner.name);
      diag.ingestStage(
        SidfStageSample(
          stage: SidfPipelineStage.orchestrator,
          health: sieOn ? SidfStageHealth.healthy : SidfStageHealth.idle,
          timestamp: DateTime.now().toUtc(),
          label: 'integration',
        ),
      );
    }
  }

  void _noteTimeline(
    String name,
    SidfTimelineCategory category, {
    String? detail,
  }) {
    _diagnostics?.recordTimeline(
      SidfTimelineEvent(
        timestamp: DateTime.now().toUtc(),
        category: category,
        name: name,
        detail: detail,
      ),
    );
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieIntegrationFailure(
        message: 'Integration Framework is disposed.',
      );
    }
  }
}
