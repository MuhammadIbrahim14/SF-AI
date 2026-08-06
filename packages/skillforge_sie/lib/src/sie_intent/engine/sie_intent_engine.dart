import 'dart:async';

import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_intent/logging/sie_intent_logger.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_engine_status.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';
import 'package:skillforge_sie/src/sie_intent/ports/intent_engine_port.dart';
import 'package:skillforge_sie/src/sie_intent/processing/sie_intent_conflict_resolver.dart';
import 'package:skillforge_sie/src/sie_intent/processing/sie_intent_mapper.dart';

/// Production Intent Engine — gesture → interaction intent semantics only.
///
/// Does not render cursors, synthesize PointerEvents, or execute UI actions.
final class SieIntentEngine implements IntentEnginePort {
  /// Creates the engine.
  SieIntentEngine({
    SieIntentContext? context,
    SieIntentPolicy policy = SieIntentPolicy.standard,
    SieIntentLogger logger = const DeveloperSieIntentLogger(),
    bool emitSuppressionDiagnostics = false,
  })  : _logger = logger,
        _emitSuppressionDiagnostics = emitSuppressionDiagnostics,
        _context = (context ?? SieIntentContext.dashboard()).copyWith(
          policy: policy,
        ),
        _mapper = SieIntentMapper(),
        _evaluator = SieIntentEvaluator();

  final SieIntentLogger _logger;
  final bool _emitSuppressionDiagnostics;
  final SieIntentMapper _mapper;
  final SieIntentEvaluator _evaluator;

  final StreamController<SieIntentEngineStatus> _statusController =
      StreamController<SieIntentEngineStatus>.broadcast();
  final StreamController<SieIntentFrameSnapshot> _snapshotController =
      StreamController<SieIntentFrameSnapshot>.broadcast();
  final StreamController<SieIntentEvent> _eventController =
      StreamController<SieIntentEvent>.broadcast();

  StreamSubscription<SieGestureFrameSnapshot>? _sub;
  SieIntentEngineStatus _status = SieIntentEngineStatus.idle();
  SieIntentEngineMetrics _metrics = const SieIntentEngineMetrics();
  SieIntentContext _context;
  final List<double> _processingSamples = [];
  bool _disposed = false;

  @override
  Stream<SieIntentEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieIntentFrameSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<SieIntentEvent> get events => _eventController.stream;

  @override
  SieIntentEngineStatus get currentStatus => _status;

  @override
  SieIntentEngineMetrics get metrics => _metrics;

  @override
  SieIntentContext get context => _context;

  @override
  SieIntentPolicy get policy => _context.policy;

  void _emitStatus(SieIntentEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({
    SieIntentContext? context,
    SieIntentPolicy? policy,
  }) async {
    _ensureNotDisposed();
    if (context != null) {
      _context = context;
    }
    if (policy != null) {
      _context = _context.copyWith(policy: policy);
    }
    _mapper.reset();
    _metrics = const SieIntentEngineMetrics();
    _logger.info('engine_initialized', {
      'policy': _context.policy.id.name,
      'route': _context.route.kind.name,
      'security': _context.securityLevel.name,
    });
    _emitStatus(
      SieIntentEngineStatus(
        health: SieIntentEngineHealth.healthy,
        initialized: true,
        running: false,
        mode: _context.paused
            ? SieInteractionMode.paused
            : SieInteractionMode.idle,
        policy: _context.policy,
        securityLevel: _context.securityLevel,
        routeKind: _context.route.kind,
        lastEvent: 'initialized',
      ),
    );
  }

  @override
  Future<void> start(Stream<SieGestureFrameSnapshot> gestureSnapshots) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SieIntentEngineHealth.healthy,
        policy: _context.policy,
        securityLevel: _context.securityLevel,
        routeKind: _context.route.kind,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = gestureSnapshots.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
        for (final e in snap.events) {
          if (!_emitSuppressionDiagnostics && e.suppressed) continue;
          if (!_eventController.isClosed) {
            _eventController.add(e);
          }
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('gesture_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieIntentEngineHealth.error,
            lastError: SieIntentEngineFailure(message: e.toString(), cause: e),
            lastEvent: 'gesture_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieIntentFrameSnapshot process(SieGestureFrameSnapshot input) {
    final sw = Stopwatch()..start();
    try {
      // Sync tracking from gesture frame (gate evaluates recovering / lost).
      _context = _context.copyWith(trackingState: input.trackingState);

      final candidates = _mapper.mapFrame(frame: input, context: _context);
      final evaluated = _evaluator.evaluate(
        candidates: candidates,
        context: _context,
      );

      final events = <SieIntentEvent>[];
      for (final c in evaluated.accepted) {
        // Skip arming-only select candidates as actionable commits.
        if (c.kind == SieIntentKind.select &&
            c.phase == SieIntentPhase.candidate &&
            c.metadata['armingOnly'] == true) {
          // Still emit as candidate phase for FSM observers (not a click).
        }
        events.add(_toEvent(c, input, suppressed: false));
      }

      var suppressedCount = 0;
      for (final (c, reason) in evaluated.denied) {
        suppressedCount++;
        if (_emitSuppressionDiagnostics || _isSignificantSuppression(reason)) {
          events.add(_toEvent(c, input, suppressed: true, reason: reason));
        }
        if (reason == SieIntentSuppressionReason.securityPolicy) {
          _logger.info('security_block', {
            'kind': c.kind.name,
            'security': _context.securityLevel.name,
          });
        } else if (reason == SieIntentSuppressionReason.routePolicy) {
          _logger.info('intent_suppressed', {
            'kind': c.kind.name,
            'reason': reason.name,
            'route': _context.route.kind.name,
          });
        }
      }

      final mode = _modeFor(
        evaluated.primaryKind,
        input.trackingState,
        _context.paused,
      );
      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final snap = SieIntentFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        mode: mode,
        events: events,
        processingMs: processingMs,
        securityLevel: _context.securityLevel,
        routeKind: _context.route.kind,
        policyId: _context.policy.id,
        primaryKind: evaluated.primaryKind,
        suppressedCount: suppressedCount,
      );

      _noteProcessed(snap, evaluated.securityBlocks, evaluated.routeBlocks);
      _logSignificant(snap);
      _maybeUpdateStatus(snap);

      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieIntentEngineHealth.degraded,
          lastError: SieIntentEngineFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieIntentFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        mode: SieInteractionMode.blocked,
        events: const [],
        processingMs: sw.elapsedMicroseconds / 1000.0,
        securityLevel: _context.securityLevel,
        routeKind: _context.route.kind,
        policyId: _context.policy.id,
      );
    }
  }

  SieIntentEvent _toEvent(
    SieIntentCandidate c,
    SieGestureFrameSnapshot input, {
    required bool suppressed,
    SieIntentSuppressionReason? reason,
  }) {
    return SieIntentEvent(
      timestamp: input.timestamp,
      frameSequence: input.frameSequence,
      kind: c.kind,
      phase: suppressed ? SieIntentPhase.cancelled : c.phase,
      sourceGesture: _parseGesture(c.sourceGesture),
      confidence: c.confidence,
      trackingState: input.trackingState,
      securityLevel: _context.securityLevel,
      routeKind: _context.route.kind,
      policyId: _context.policy.id,
      progress: c.progress,
      axisDelta: c.axisDelta,
      position: c.position,
      targetId: c.targetId,
      suppressed: suppressed,
      suppressionReason: reason,
      metadata: {
        ...c.metadata,
        'route': _context.route.kind.name,
        'security': _context.securityLevel.name,
      },
    );
  }

  static SieGestureKind? _parseGesture(String name) {
    for (final k in SieGestureKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }

  static bool _isSignificantSuppression(SieIntentSuppressionReason reason) {
    return reason == SieIntentSuppressionReason.securityPolicy ||
        reason == SieIntentSuppressionReason.routePolicy ||
        reason == SieIntentSuppressionReason.futureNotActivated;
  }

  static SieInteractionMode _modeFor(
    SieIntentKind? primary,
    SieTrackingReliabilityState tracking,
    bool paused,
  ) {
    if (paused) return SieInteractionMode.paused;
    if (tracking == SieTrackingReliabilityState.disabled ||
        tracking == SieTrackingReliabilityState.error ||
        tracking == SieTrackingReliabilityState.lostTracking) {
      return SieInteractionMode.blocked;
    }
    return switch (primary) {
      SieIntentKind.moveCursor => SieInteractionMode.moving,
      SieIntentKind.hoverEnter || SieIntentKind.hoverExit =>
        SieInteractionMode.hovering,
      SieIntentKind.select ||
      SieIntentKind.selectHold ||
      SieIntentKind.selectRelease ||
      SieIntentKind.dwellSelect =>
        SieInteractionMode.selecting,
      SieIntentKind.beginDrag ||
      SieIntentKind.updateDrag ||
      SieIntentKind.endDrag =>
        SieInteractionMode.dragging,
      SieIntentKind.scrollDelta => SieInteractionMode.scrolling,
      SieIntentKind.pauseSie => SieInteractionMode.paused,
      _ => SieInteractionMode.idle,
    };
  }

  void _noteProcessed(
    SieIntentFrameSnapshot snap,
    int securityBlocks,
    int routeBlocks,
  ) {
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    final avg = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    final actionable = snap.actionable.length;
    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      intentsGenerated: _metrics.intentsGenerated + actionable,
      intentsSuppressed: _metrics.intentsSuppressed + snap.suppressedCount,
      securityBlocks: _metrics.securityBlocks + securityBlocks,
      routeBlocks: _metrics.routeBlocks + routeBlocks,
      averageProcessingMs: avg,
      lastProcessingMs: snap.processingMs,
    );
  }

  void _logSignificant(SieIntentFrameSnapshot snap) {
    for (final e in snap.events) {
      if (e.suppressed) {
        if (e.suppressionReason == SieIntentSuppressionReason.securityPolicy ||
            e.suppressionReason == SieIntentSuppressionReason.routePolicy) {
          // Already logged in process for those.
          continue;
        }
        continue;
      }
      if (e.kind == SieIntentKind.select &&
          e.phase == SieIntentPhase.candidate) {
        continue; // avoid per-arming spam
      }
      if (e.kind == SieIntentKind.moveCursor &&
          e.phase == SieIntentPhase.active) {
        continue; // never log every frame
      }
      if (e.kind == SieIntentKind.updateDrag ||
          (e.kind == SieIntentKind.scrollDelta &&
              e.phase == SieIntentPhase.active)) {
        continue;
      }
      _logger.info('intent_generated', {
        'kind': e.kind.name,
        'phase': e.phase.name,
        'confidence': e.confidence,
      });
    }
  }

  void _maybeUpdateStatus(SieIntentFrameSnapshot snap) {
    if (snap.mode != _status.mode ||
        snap.primaryKind != _status.primaryKind ||
        snap.securityLevel != _status.securityLevel ||
        snap.routeKind != _status.routeKind) {
      _emitStatus(
        _status.copyWith(
          mode: snap.mode,
          primaryKind: snap.primaryKind,
          clearPrimary: snap.primaryKind == null,
          policy: _context.policy,
          securityLevel: snap.securityLevel,
          routeKind: snap.routeKind,
          health: SieIntentEngineHealth.healthy,
          lastEvent: 'intent_state',
        ),
      );
    }
  }

  @override
  Future<void> updateContext(SieIntentContext context) async {
    _ensureNotDisposed();
    final prevRoute = _context.route.kind;
    final prevSecurity = _context.securityLevel;
    final prevPolicy = _context.policy.id;
    _context = context;
    if (prevRoute != context.route.kind ||
        prevSecurity != context.securityLevel ||
        prevPolicy != context.policy.id) {
      _logger.info('policy_change', {
        'route': context.route.kind.name,
        'security': context.securityLevel.name,
        'policy': context.policy.id.name,
      });
    }
    _emitStatus(
      _status.copyWith(
        policy: context.policy,
        securityLevel: context.securityLevel,
        routeKind: context.route.kind,
        mode: context.paused ? SieInteractionMode.paused : _status.mode,
        lastEvent: 'context_updated',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> setPolicy(SieIntentPolicy policy) async {
    _ensureNotDisposed();
    _context = _context.copyWith(policy: policy);
    _logger.info('policy_change', {'policy': policy.id.name});
    _emitStatus(
      _status.copyWith(
        policy: policy,
        lastEvent: 'policy_changed',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> pauseSession() async {
    _ensureNotDisposed();
    _context = _context.copyWith(paused: true);
    final event = SieIntentEvent(
      timestamp: DateTime.now().toUtc(),
      frameSequence: -1,
      kind: SieIntentKind.pauseSie,
      phase: SieIntentPhase.completed,
      sourceGesture: null,
      confidence: 1,
      trackingState: _context.trackingState,
      securityLevel: _context.securityLevel,
      routeKind: _context.route.kind,
      policyId: _context.policy.id,
    );
    _logger.info('intent_generated', {'kind': 'pauseSie'});
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    _emitStatus(
      _status.copyWith(
        mode: SieInteractionMode.paused,
        primaryKind: SieIntentKind.pauseSie,
        lastEvent: 'paused',
      ),
    );
  }

  @override
  Future<void> resumeSession() async {
    _ensureNotDisposed();
    _context = _context.copyWith(paused: false);
    final event = SieIntentEvent(
      timestamp: DateTime.now().toUtc(),
      frameSequence: -1,
      kind: SieIntentKind.resumeSie,
      phase: SieIntentPhase.completed,
      sourceGesture: null,
      confidence: 1,
      trackingState: _context.trackingState,
      securityLevel: _context.securityLevel,
      routeKind: _context.route.kind,
      policyId: _context.policy.id,
    );
    _logger.info('intent_generated', {'kind': 'resumeSie'});
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    _emitStatus(
      _status.copyWith(
        mode: SieInteractionMode.idle,
        primaryKind: SieIntentKind.resumeSie,
        lastEvent: 'resumed',
      ),
    );
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _sub?.cancel();
    _sub = null;
    _logger.info('engine_stopped');
    _emitStatus(
      _status.copyWith(
        running: false,
        health: SieIntentEngineHealth.healthy,
        lastEvent: 'stopped',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    _mapper.reset();
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieIntentEngineHealth.disposed,
        running: false,
        initialized: false,
        mode: SieInteractionMode.idle,
        clearPrimary: true,
        lastEvent: 'disposed',
      ),
    );
    await _eventController.close();
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieIntentEngineFailure(message: 'Intent engine is disposed.');
    }
  }
}
