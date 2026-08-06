import 'dart:async';

import 'package:skillforge_sie/src/sie_arbitration/ports/input_arbitration_engine_port.dart';
import 'package:skillforge_sie/src/sie_calibration/ports/calibration_engine_port.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lifecycle_state.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_port.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_cpmf/ports/cpmf_port.dart';
import 'package:skillforge_sie/src/sie_confidence/ports/confidence_engine_port.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_cursor/ports/virtual_cursor_engine_port.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_feature_flags.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_gesture/ports/gesture_engine_port.dart';
import 'package:skillforge_sie/src/sie_intent/ports/intent_engine_port.dart';
import 'package:skillforge_sie/src/sie_integration/ports/sie_integration_port.dart';
import 'package:skillforge_sie/src/sie_landmarks/ports/landmark_engine_port.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_orchestrator_port.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/flutter_pointer_bridge_port.dart';
import 'package:skillforge_sie/src/sie_rollout/ports/progressive_rollout_port.dart';
import 'package:skillforge_sie/src/sie_spatial/ports/spatial_coordinate_engine_port.dart';
import 'package:skillforge_sie/src/sie_srdcr/logging/srdcr_logger.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_platform_context.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_registry_snapshot.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_service_descriptor.dart';
import 'package:skillforge_sie/src/sie_srdcr/ports/srdcr_port.dart';
import 'package:skillforge_sie/src/sie_srdcr/processing/srdcr_default_registrations.dart';
import 'package:skillforge_sie/src/sie_srdcr/processing/srdcr_service_registry.dart';
import 'package:skillforge_sie/src/sie_vision/ports/vision_runtime_port.dart';

/// Production Service Registry & Dependency Composition Root.
final class SieServiceRegistryCompositionRoot implements SrdcrPort {
  /// Creates composition root.
  SieServiceRegistryCompositionRoot({
    this.useTestDoubles = false,
    SrdcrLogger logger = const DeveloperSrdcrLogger(),
  }) : _logger = logger;

  /// When true, uses fake camera / mock vision (tests / CI).
  final bool useTestDoubles;

  final SrdcrLogger _logger;
  final SrdcrServiceRegistry _registry = SrdcrServiceRegistry();

  final StreamController<SrdcrStatus> _statusController =
      StreamController<SrdcrStatus>.broadcast();
  final StreamController<SrdcrRegistrySnapshot> _snapshotController =
      StreamController<SrdcrRegistrySnapshot>.broadcast();

  SrdcrStatus _status = SrdcrStatus.idle();
  SrdcrRegistrySnapshot _snapshot = SrdcrRegistrySnapshot.idle();
  bool _bootstrapped = false;
  bool _disposed = false;
  bool _pipelineStarted = false;
  Future<void> _queue = Future<void>.value();

  @override
  Stream<SrdcrStatus> get status => _statusController.stream;

  @override
  Stream<SrdcrRegistrySnapshot> get snapshots => _snapshotController.stream;

  @override
  SrdcrStatus get currentStatus => _status;

  @override
  SrdcrRegistrySnapshot get latestSnapshot => _snapshot;

  @override
  SrdcrServiceRegistry get registry => _registry;

  @override
  bool get isReady => _bootstrapped && _status.phase == SrdcrPhase.ready;

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

  void _publish(SrdcrRegistrySnapshot snap, {required String event}) {
    _snapshot = snap;
    _status = SrdcrStatus(
      phase: snap.phase,
      health: snap.health,
      ready: snap.phase == SrdcrPhase.ready,
      startupDurationMs: snap.startupDurationMs,
      lastEvent: event,
    );
    if (!_statusController.isClosed) _statusController.add(_status);
    if (!_snapshotController.isClosed) _snapshotController.add(snap);
  }

  @override
  Future<void> bootstrap({
    required SiePlatformKind platform,
    Map<SrdcrServiceId, SrdcrFactory>? overrides,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        if (_bootstrapped) {
          throw SieSrdcrFailure(message: 'SRDCR already bootstrapped');
        }
        final sw = Stopwatch()..start();
        try {
          _registry.reset();
          _publish(
            SrdcrRegistrySnapshot(
              timestamp: DateTime.now().toUtc(),
              phase: SrdcrPhase.registering,
              health: SrdcrHealth.idle,
              registered: const [],
              initOrder: const [],
              startupDurationMs: 0,
            ),
            event: 'registering',
          );

          SrdcrDefaultRegistrations.registerAll(
            _registry,
            platform: platform,
            useTestDoubles: useTestDoubles,
          );
          _registry.overrideFactory(
            SrdcrServiceId.platform,
            (_) => SrdcrPlatformContext(platform),
          );
          if (overrides != null) {
            for (final e in overrides.entries) {
              _registry.overrideFactory(e.key, e.value);
              _logger.info('service_registered', {
                'id': e.key.name,
                'override': true,
              });
            }
          }
          for (final id in _registry.registeredIds) {
            _logger.info('service_registered', {'id': id.name});
          }

          _publish(
            _snapshot.copyWithPhase(SrdcrPhase.validating),
            event: 'validating',
          );
          _registry.seal();

          _publish(
            _snapshot.copyWithPhase(SrdcrPhase.constructing),
            event: 'constructing',
          );
          _registry.beginScope();
          _registry.constructAllSingletons();

          _publish(
            _snapshot.copyWithPhase(SrdcrPhase.starting),
            event: 'starting',
          );
          await _runStartupPipeline(platform);

          sw.stop();
          final order = SrdcrGraphValidator.sortedInitOrder(
            _registry.descriptors,
          );
          _bootstrapped = true;
          _publish(
            SrdcrRegistrySnapshot(
              timestamp: DateTime.now().toUtc(),
              phase: SrdcrPhase.ready,
              health: SrdcrHealth.healthy,
              registered: _registry.registeredIds,
              initOrder: order,
              startupDurationMs: sw.elapsedMicroseconds / 1000.0,
            ),
            event: 'initialization_complete',
          );
          _logger.info('initialization_complete', {
            'ms': _snapshot.startupDurationMs,
            'services': _registry.registeredIds.length,
          });
          _noteSidf('srdcr_ready');
        } catch (e, st) {
          sw.stop();
          _logger.error('initialization_failed', {'error': '$e'}, e);
          final registered = _registry.registeredIds;
          try {
            await _runShutdownPipeline();
          } catch (_) {}
          _registry.reset();
          _bootstrapped = false;
          _pipelineStarted = false;
          _publish(
            SrdcrRegistrySnapshot(
              timestamp: DateTime.now().toUtc(),
              phase: SrdcrPhase.failed,
              health: SrdcrHealth.failed,
              registered: registered,
              initOrder: const [],
              startupDurationMs: sw.elapsedMicroseconds / 1000.0,
              failures: ['$e'],
              metadata: {'stack': '$st'},
            ),
            event: 'initialization_failed',
          );
          Error.throwWithStackTrace(
            e is SieSrdcrFailure
                ? e
                : SieSrdcrFailure(message: 'Bootstrap failed: $e', cause: e),
            st,
          );
        }
      });

  Future<void> _runStartupPipeline(SiePlatformKind platform) async {
    // Configuration → Diagnostics → Platform → … → Integration → Rollout
    await diagnostics.initialize(flags: SidfFeatureFlags.forBuildMode());
    await cpmf.initialize(
      platform: platform,
      environment: CpmfEnvironment.production,
    );
    // Web live MediaPipe owns getUserMedia — skip Flutter camera init to avoid
    // double prompts / stream conflicts with the JS VIDEO bridge.
    if (platform != SiePlatformKind.web || useTestDoubles) {
      try {
        await camera.initialize();
      } on SiePermissionDeniedFailure catch (e) {
        _logger.warn('camera_init_deferred', {'reason': '$e'});
      } on SieFailure catch (e) {
        if (e.code.contains('permission') || e.code.contains('camera')) {
          _logger.warn('camera_init_deferred', {'reason': '$e'});
        } else {
          rethrow;
        }
      }
    }
    await vision.initialize();
    await landmarks.initialize();
    await spatial.initialize();
    await calibration.initialize();
    await confidence.initialize();
    await gestures.initialize();
    await intent.initialize();
    await cursor.initialize();
    await pointer.initialize();
    await arbitration.initialize();
    await orchestrator.initialize();
    await integration.register();
    await integration.initialize();
    // Rollout initialize is host-driven (needs userKey/segment); construct only.
  }

  @override
  Future<void> startRuntimePipeline() => _serialized(() async {
        _ensureReady();
        if (_pipelineStarted) return;
        try {
          // Web live capture owns getUserMedia inside MediaPipe — skip Flutter
          // camera image stream (often unimplemented on Chrome).
          final useLiveVision = !useTestDoubles &&
              _registry.isConstructed(SrdcrServiceId.vision);

          if (!useLiveVision || !_visionSupportsLive()) {
            final camState = camera.currentStatus.state;
            if (camState != SieCameraLifecycleState.ready &&
                camState != SieCameraLifecycleState.streaming) {
              await camera.initialize();
            }
            await camera.start();
          } else {
            _logger.info('runtime_pipeline_web_live_vision');
          }

          await vision.start(camera.frames);
          await landmarks.start(vision.results);
          await spatial.start(landmarks.snapshots);
          await calibration.start(spatial.snapshots);
          await confidence.start(calibration.snapshots);
          await gestures.start(confidence.snapshots);
          await intent.start(gestures.snapshots);
          await cursor.start(intent.snapshots);
          await pointer.start(
            cursorSnapshots: cursor.snapshots,
            intentSnapshots: intent.snapshots,
          );
          _pipelineStarted = true;
          _logger.info('runtime_pipeline_started');
        } on SiePermissionDeniedFailure catch (e) {
          _logger.warn('runtime_pipeline_deferred', {'reason': '$e'});
          rethrow;
        }
      });

  bool _visionSupportsLive() {
    try {
      // Web MediaPipe backend advertises live capture via Vision start path.
      // Detect by platform context registered at bootstrap.
      final ctx = _registry.resolve(SrdcrServiceId.platform);
      if (ctx is SrdcrPlatformContext) {
        return ctx.platform == SiePlatformKind.web;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<void> shutdown() => _serialized(() async {
        _ensureNotDisposed();
        _logger.info('shutdown_started');
        _publish(
          _snapshot.copyWithPhase(SrdcrPhase.shuttingDown),
          event: 'shutdown_started',
        );
        await _runShutdownPipeline();
        _registry.endScope();
        _registry.reset();
        _bootstrapped = false;
        _pipelineStarted = false;
        _publish(
          SrdcrRegistrySnapshot(
            timestamp: DateTime.now().toUtc(),
            phase: SrdcrPhase.disposed,
            health: SrdcrHealth.disposed,
            registered: const [],
            initOrder: const [],
            startupDurationMs: _snapshot.startupDurationMs,
          ),
          event: 'shutdown_complete',
        );
        _logger.info('shutdown_complete');
      });

  Future<void> _runShutdownPipeline() async {
    // Reverse: stop runtime, then dispose frameworks.
    final order = SrdcrServiceCatalog.shutdownOrder;
    for (final id in order) {
      if (!_registry.isConstructed(id)) continue;
      try {
        await _stopAndDispose(id);
      } catch (e) {
        _logger.warn('shutdown_service_failed', {
          'id': id.name,
          'error': '$e',
        });
      }
    }
  }

  Future<void> _stopAndDispose(SrdcrServiceId id) async {
    switch (id) {
      case SrdcrServiceId.camera:
        await camera.stop();
        await camera.dispose();
      case SrdcrServiceId.vision:
        await vision.stop();
        await vision.dispose();
      case SrdcrServiceId.landmarks:
        await landmarks.stop();
        await landmarks.dispose();
      case SrdcrServiceId.spatial:
        await spatial.stop();
        await spatial.dispose();
      case SrdcrServiceId.calibration:
        await calibration.stop();
        await calibration.dispose();
      case SrdcrServiceId.confidence:
        await confidence.stop();
        await confidence.dispose();
      case SrdcrServiceId.gestures:
        await gestures.stop();
        await gestures.dispose();
      case SrdcrServiceId.intent:
        await intent.stop();
        await intent.dispose();
      case SrdcrServiceId.cursor:
        await cursor.stop();
        await cursor.dispose();
      case SrdcrServiceId.pointer:
        await pointer.stop();
        await pointer.dispose();
      case SrdcrServiceId.arbitration:
        await arbitration.stop();
        await arbitration.dispose();
      case SrdcrServiceId.orchestrator:
        await orchestrator.stop();
        await orchestrator.dispose();
      case SrdcrServiceId.integration:
        await integration.dispose();
      case SrdcrServiceId.rollout:
        await rollout.dispose();
      case SrdcrServiceId.cpmf:
        await cpmf.dispose();
      case SrdcrServiceId.diagnostics:
        await diagnostics.dispose();
      case SrdcrServiceId.platform:
        break;
    }
  }

  @override
  T resolve<T extends Object>(SrdcrServiceId id) {
    _ensureReady();
    return _registry.resolve<T>(id);
  }

  @override
  CpmfPort get cpmf => _registry.resolve(SrdcrServiceId.cpmf);

  @override
  SidfDiagnosticsPort get diagnostics =>
      _registry.resolve(SrdcrServiceId.diagnostics);

  @override
  CameraPort get camera => _registry.resolve(SrdcrServiceId.camera);

  @override
  VisionRuntimePort get vision => _registry.resolve(SrdcrServiceId.vision);

  @override
  LandmarkEnginePort get landmarks =>
      _registry.resolve(SrdcrServiceId.landmarks);

  @override
  SpatialCoordinateEnginePort get spatial =>
      _registry.resolve(SrdcrServiceId.spatial);

  @override
  CalibrationEnginePort get calibration =>
      _registry.resolve(SrdcrServiceId.calibration);

  @override
  ConfidenceEnginePort get confidence =>
      _registry.resolve(SrdcrServiceId.confidence);

  @override
  GestureEnginePort get gestures => _registry.resolve(SrdcrServiceId.gestures);

  @override
  IntentEnginePort get intent => _registry.resolve(SrdcrServiceId.intent);

  @override
  VirtualCursorEnginePort get cursor => _registry.resolve(SrdcrServiceId.cursor);

  @override
  FlutterPointerBridgePort get pointer =>
      _registry.resolve(SrdcrServiceId.pointer);

  @override
  InputArbitrationEnginePort get arbitration =>
      _registry.resolve(SrdcrServiceId.arbitration);

  @override
  InteractionOrchestratorPort get orchestrator =>
      _registry.resolve(SrdcrServiceId.orchestrator);

  @override
  SieIntegrationPort get integration =>
      _registry.resolve(SrdcrServiceId.integration);

  @override
  ProgressiveRolloutPort get rollout =>
      _registry.resolve(SrdcrServiceId.rollout);

  @override
  Map<String, Object?> diagnosticsReport() => {
        ..._snapshot.toDiagnostics(),
        'pipelineStarted': _pipelineStarted,
        'bootstrapped': _bootstrapped,
        'dependencyGraph': {
          for (final d in _registry.descriptors)
            d.id.name: d.dependsOn.map((e) => e.name).toList(growable: false),
        },
      };

  @override
  Future<void> dispose() => _serialized(() async {
        if (_disposed) return;
        if (_bootstrapped) {
          await _runShutdownPipeline();
          _registry.reset();
        }
        _disposed = true;
        _bootstrapped = false;
        _publish(
          SrdcrRegistrySnapshot(
            timestamp: DateTime.now().toUtc(),
            phase: SrdcrPhase.disposed,
            health: SrdcrHealth.disposed,
            registered: const [],
            initOrder: const [],
            startupDurationMs: 0,
          ),
          event: 'disposed',
        );
        await _statusController.close();
        await _snapshotController.close();
      });

  void _noteSidf(String name) {
    try {
      if (!_registry.isConstructed(SrdcrServiceId.diagnostics)) return;
      diagnostics.recordTimeline(
        SidfTimelineEvent(
          timestamp: DateTime.now().toUtc(),
          category: SidfTimelineCategory.lifecycle,
          name: name,
        ),
      );
    } catch (_) {}
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieSrdcrFailure(message: 'SRDCR is disposed.');
    }
  }

  void _ensureReady() {
    _ensureNotDisposed();
    if (!_bootstrapped) {
      throw SieSrdcrFailure(message: 'SRDCR not bootstrapped.');
    }
  }
}

extension on SrdcrRegistrySnapshot {
  SrdcrRegistrySnapshot copyWithPhase(SrdcrPhase phase) => SrdcrRegistrySnapshot(
        timestamp: DateTime.now().toUtc(),
        phase: phase,
        health: health,
        registered: registered,
        initOrder: initOrder,
        startupDurationMs: startupDurationMs,
        failures: failures,
        metadata: metadata,
      );
}
