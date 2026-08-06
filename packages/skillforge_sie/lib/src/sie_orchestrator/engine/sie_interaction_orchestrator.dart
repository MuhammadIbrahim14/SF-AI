import 'dart:async';

import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_snapshot.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/logging/sie_orchestrator_logger.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestration_snapshot.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_status.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_dispatch_port.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_orchestrator_port.dart';
import 'package:skillforge_sie/src/sie_orchestrator/processing/sie_orchestration_coordinator.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Production Interaction Orchestrator — application interaction gateway.
final class SieInteractionOrchestrator implements InteractionOrchestratorPort {
  /// Creates the orchestrator.
  SieInteractionOrchestrator({
    SieOrchestrationContext? context,
    InteractionDispatchPort dispatcher = const NopInteractionDispatcher(),
    SieOrchestratorLogger logger = const DeveloperSieOrchestratorLogger(),
  })  : _logger = logger,
        _dispatcher = dispatcher,
        _context = context ??
            const SieOrchestrationContext(
              lifecycle: SieAppLifecycleState.cold,
            ),
        _coordinator = const SieOrchestrationCoordinator();

  final SieOrchestratorLogger _logger;
  final SieOrchestrationCoordinator _coordinator;
  InteractionDispatchPort _dispatcher;
  SieOrchestrationContext _context;

  final StreamController<SieOrchestratorStatus> _statusController =
      StreamController<SieOrchestratorStatus>.broadcast();
  final StreamController<SieOrchestrationSnapshot> _snapshotController =
      StreamController<SieOrchestrationSnapshot>.broadcast();

  StreamSubscription<SieArbitrationSnapshot>? _arbSub;
  StreamSubscription<List<SiePointerEvent>>? _ptrSub;
  List<SiePointerEvent> _pendingSie = const [];
  SieArbitrationSnapshot? _latestArb;
  SieOrchestratorStatus _status = SieOrchestratorStatus.idle();
  SieOrchestratorMetrics _metrics = const SieOrchestratorMetrics();
  final List<double> _processingSamples = [];
  bool _disposed = false;
  SieOrchestrationMode _mode = SieOrchestrationMode.disabled;

  @override
  Stream<SieOrchestratorStatus> get status => _statusController.stream;

  @override
  Stream<SieOrchestrationSnapshot> get snapshots => _snapshotController.stream;

  @override
  SieOrchestratorStatus get currentStatus => _status;

  @override
  SieOrchestratorMetrics get metrics => _metrics;

  @override
  SieOrchestrationContext get context => _context;

  @override
  bool get interactionEnabled => _context.interactionEnabled;

  @override
  SieOrchestrationMode get mode => _mode;

  void _emitStatus(SieOrchestratorStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({
    SieOrchestrationContext? context,
    InteractionDispatchPort? dispatcher,
  }) async {
    _ensureNotDisposed();
    if (context != null) _context = context;
    if (dispatcher != null) _dispatcher = dispatcher;
    _metrics = const SieOrchestratorMetrics();
    _pendingSie = const [];
    _latestArb = null;
    _mode = SieOrchestrationMode.disabled;
    _logger.info('application_started', {
      'lifecycle': _context.lifecycle.name,
      'route': _context.routeKind.name,
    });
    _emitStatus(
      SieOrchestratorStatus(
        health: SieOrchestratorHealth.healthy,
        initialized: true,
        running: false,
        lifecycle: _context.lifecycle,
        mode: _mode,
        interactionEnabled: _context.interactionEnabled,
        lastEvent: 'initialized',
      ),
    );
  }

  @override
  Future<void> start({
    required Stream<SieArbitrationSnapshot> arbitrationSnapshots,
    Stream<List<SiePointerEvent>>? siePointerBatches,
  }) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _arbSub?.cancel();
    await _ptrSub?.cancel();
    _logger.info('interaction_enabled', {
      'enabled': _context.interactionEnabled,
    });
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SieOrchestratorHealth.healthy,
        lastEvent: 'started',
        clearError: true,
      ),
    );

    if (siePointerBatches != null) {
      _ptrSub = siePointerBatches.listen(
        (batch) => _pendingSie = List.unmodifiable(batch),
        onError: (Object e, StackTrace st) {
          _logger.error('pointer_batch_error', null, e);
        },
      );
    }

    _arbSub = arbitrationSnapshots.listen(
      (arb) {
        final batch = _pendingSie;
        _pendingSie = const [];
        final snap = process(
          SieOrchestrationFrameInput(
            timestamp: arb.timestamp,
            arbitration: arb,
            siePointerEvents: batch,
            frameSequence: arb.frameSequence,
          ),
        );
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('arbitration_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieOrchestratorHealth.error,
            lastError:
                SieOrchestratorFailure(message: e.toString(), cause: e),
            lastEvent: 'arbitration_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieOrchestrationSnapshot process(SieOrchestrationFrameInput input) {
    final sw = Stopwatch()..start();
    try {
      _latestArb = input.arbitration;
      // Align route from arbitration when host hasn't overridden mid-frame.
      final ctx = _context.copyWith(
        routeKind: input.arbitration.routeKind,
      );

      final gate = _coordinator.evaluate(
        context: ctx,
        arbitration: input.arbitration,
        siePointerEvents: input.siePointerEvents,
      );
      _mode = gate.mode;

      if (gate.decision == SieDispatchDecision.dispatched &&
          gate.events.isNotEmpty) {
        unawaited(_safeDispatch(gate.events));
      }

      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final snap = SieOrchestrationSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence ?? input.arbitration.frameSequence,
        lifecycle: ctx.lifecycle,
        mode: gate.mode,
        routeKind: ctx.routeKind,
        securityLevel: ctx.securityLevel,
        owner: input.arbitration.owner,
        focus: ctx.focus,
        accessibility: ctx.accessibility,
        availability: ctx.availability,
        modal: ctx.modal,
        interactionEnabled: ctx.interactionEnabled,
        sieDispatchEnabled: gate.sieDispatchEnabled,
        decision: gate.decision,
        dispatchedEvents: gate.events,
        processingMs: processingMs,
        metadata: {
          'forwardsSie': input.arbitration.forwardsSiePointers,
          'arbReason': input.arbitration.reason.name,
        },
      );

      _noteProcessed(snap, input.siePointerEvents.length);
      _logSignificant(snap);
      _maybeUpdateStatus(snap);
      unawaited(_safeSnapshot(snap));
      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieOrchestratorHealth.degraded,
          lastError: SieOrchestratorFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieOrchestrationSnapshot.idle(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence ?? 0,
      );
    }
  }

  Future<void> _safeDispatch(List<SiePointerEvent> events) async {
    try {
      await _dispatcher.dispatch(events);
    } catch (e) {
      _logger.error('dispatch_failed', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieOrchestratorHealth.degraded,
          lastError: SieOrchestratorFailure(message: e.toString(), cause: e),
          lastEvent: 'dispatch_failed',
        ),
      );
    }
  }

  Future<void> _safeSnapshot(SieOrchestrationSnapshot snap) async {
    try {
      await _dispatcher.onSnapshot(snap);
    } catch (_) {
      // Host snapshot hooks must not break orchestration.
    }
  }

  void _noteProcessed(SieOrchestrationSnapshot snap, int attempted) {
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    final avg = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    final blocked = snap.decision == SieDispatchDecision.dispatched
        ? 0
        : attempted;

    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      eventsDispatched: _metrics.eventsDispatched + snap.dispatchedCount,
      eventsBlocked: _metrics.eventsBlocked + blocked,
      averageProcessingMs: avg,
      lastProcessingMs: snap.processingMs,
    );
  }

  void _logSignificant(SieOrchestrationSnapshot snap) {
    // Avoid per-frame noise; significant pointer edges only.
    if (snap.decision != SieDispatchDecision.dispatched) return;
    for (final e in snap.dispatchedEvents) {
      if (e.kind == SiePointerEventKind.down ||
          e.kind == SiePointerEventKind.up ||
          e.kind == SiePointerEventKind.cancel) {
        _logger.info('dispatch_edge', {
          'kind': e.kind.name,
          'owner': snap.owner.name,
        });
      }
    }
  }

  void _maybeUpdateStatus(SieOrchestrationSnapshot snap) {
    if (snap.mode != _status.mode ||
        snap.lifecycle != _status.lifecycle ||
        snap.interactionEnabled != _status.interactionEnabled) {
      _emitStatus(
        _status.copyWith(
          mode: snap.mode,
          lifecycle: snap.lifecycle,
          interactionEnabled: snap.interactionEnabled,
          health: SieOrchestratorHealth.healthy,
          lastEvent: 'orchestration_state',
        ),
      );
    }
  }

  @override
  Future<void> setLifecycle(SieAppLifecycleState lifecycle) async {
    _ensureNotDisposed();
    final prev = _context.lifecycle;
    _context = _context.copyWith(lifecycle: lifecycle);
    _metrics = _metrics.copyWith(
      lifecycleTransitions: _metrics.lifecycleTransitions + 1,
    );
    _logger.info('lifecycle_change', {
      'from': prev.name,
      'to': lifecycle.name,
    });
    if (lifecycle == SieAppLifecycleState.resumed) {
      _logger.info('interaction_enabled', {'enabled': _context.interactionEnabled});
    } else if (lifecycle == SieAppLifecycleState.paused ||
        lifecycle == SieAppLifecycleState.background ||
        lifecycle == SieAppLifecycleState.shutdown) {
      _logger.info('interaction_disabled', {'lifecycle': lifecycle.name});
    }
    _emitStatus(
      _status.copyWith(
        lifecycle: lifecycle,
        lastEvent: 'lifecycle_changed',
      ),
    );
    _reprocessIfPossible();
  }

  @override
  Future<void> setRoute({
    required SieRouteCapabilityKind routeKind,
    SieSecurityLevel? securityLevel,
  }) async {
    _ensureNotDisposed();
    final prev = _context.routeKind;
    _context = _context.copyWith(
      routeKind: routeKind,
      securityLevel: securityLevel,
    );
    _metrics = _metrics.copyWith(
      routeTransitions: _metrics.routeTransitions + 1,
    );
    _logger.info('route_change', {
      'from': prev.name,
      'to': routeKind.name,
      'security': (securityLevel ?? _context.securityLevel).name,
    });
    _reprocessIfPossible();
  }

  @override
  Future<void> setFocus(SieFocusState focus) async {
    _ensureNotDisposed();
    final changed = focus.windowFocused != _context.focus.windowFocused ||
        focus.kind != _context.focus.kind;
    _context = _context.copyWith(focus: focus);
    if (changed) {
      _metrics = _metrics.copyWith(
        focusTransitions: _metrics.focusTransitions + 1,
      );
    }
    _reprocessIfPossible();
  }

  @override
  Future<void> setModal(SieModalKind modal) async {
    _ensureNotDisposed();
    _context = _context.copyWith(modal: modal);
    _reprocessIfPossible();
  }

  @override
  Future<void> setAccessibility(SieAccessibilityState accessibility) async {
    _ensureNotDisposed();
    _context = _context.copyWith(accessibility: accessibility);
  }

  @override
  Future<void> setAvailability(SieInteractionAvailability availability) async {
    _ensureNotDisposed();
    _context = _context.copyWith(availability: availability);
    _reprocessIfPossible();
  }

  @override
  Future<void> setInteractionEnabled(bool enabled) async {
    _ensureNotDisposed();
    _context = _context.copyWith(interactionEnabled: enabled);
    _logger.info(
      enabled ? 'interaction_enabled' : 'interaction_disabled',
      {'enabled': enabled},
    );
    _emitStatus(
      _status.copyWith(
        interactionEnabled: enabled,
        lastEvent: 'interaction_toggled',
      ),
    );
    _reprocessIfPossible();
  }

  @override
  Future<void> setDispatcher(InteractionDispatchPort dispatcher) async {
    _ensureNotDisposed();
    _dispatcher = dispatcher;
  }

  @override
  Future<void> notifyRecoveryCompleted() async {
    _ensureNotDisposed();
    _metrics = _metrics.copyWith(
      recoveryCount: _metrics.recoveryCount + 1,
    );
    _logger.info('recovery_completed', {
      'count': _metrics.recoveryCount,
    });
    if (_mode == SieOrchestrationMode.recovering) {
      _mode = SieOrchestrationMode.coordinating;
    }
  }

  void _reprocessIfPossible() {
    final arb = _latestArb;
    if (arb == null) return;
    final snap = process(
      SieOrchestrationFrameInput(
        timestamp: DateTime.now().toUtc(),
        arbitration: arb,
        siePointerEvents: const [],
        frameSequence: arb.frameSequence,
      ),
    );
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snap);
    }
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _arbSub?.cancel();
    await _ptrSub?.cancel();
    _arbSub = null;
    _ptrSub = null;
    _logger.info('engine_stopped');
    _emitStatus(
      _status.copyWith(
        running: false,
        health: SieOrchestratorHealth.healthy,
        lastEvent: 'stopped',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _arbSub?.cancel();
    await _ptrSub?.cancel();
    _arbSub = null;
    _ptrSub = null;
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieOrchestratorHealth.disposed,
        running: false,
        initialized: false,
        lifecycle: SieAppLifecycleState.shutdown,
        mode: SieOrchestrationMode.disabled,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieOrchestratorFailure(message: 'Orchestrator is disposed.');
    }
  }
}
