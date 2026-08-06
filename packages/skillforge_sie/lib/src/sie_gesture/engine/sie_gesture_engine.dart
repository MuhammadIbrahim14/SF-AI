import 'dart:async';

import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_snapshot.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_gesture/logging/sie_gesture_logger.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_engine_status.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';
import 'package:skillforge_sie/src/sie_gesture/ports/gesture_engine_port.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_evaluator.dart';

/// Production Gesture Engine — IDS vocabulary recognition only.
///
/// Does not move the cursor, execute clicks, or generate intents.
final class SieGestureEngine implements GestureEnginePort {
  /// Creates the engine.
  SieGestureEngine({
    SieGesturePolicy policy = SieGesturePolicy.standard,
    SieGestureLogger logger = const DeveloperSieGestureLogger(),
  })  : _logger = logger,
        _evaluator = SieGestureEvaluator(policy: policy);

  final SieGestureLogger _logger;
  final SieGestureEvaluator _evaluator;

  final StreamController<SieGestureEngineStatus> _statusController =
      StreamController<SieGestureEngineStatus>.broadcast();
  final StreamController<SieGestureFrameSnapshot> _snapshotController =
      StreamController<SieGestureFrameSnapshot>.broadcast();
  final StreamController<SieGestureEvent> _eventController =
      StreamController<SieGestureEvent>.broadcast();

  StreamSubscription<SieConfidenceFrameSnapshot>? _sub;
  SieGestureEngineStatus _status = SieGestureEngineStatus.idle();
  SieGestureEngineMetrics _metrics = const SieGestureEngineMetrics();
  final List<double> _processingSamples = [];
  final List<double> _confidenceSamples = [];
  bool _disposed = false;

  @override
  Stream<SieGestureEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieGestureFrameSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<SieGestureEvent> get events => _eventController.stream;

  @override
  SieGestureEngineStatus get currentStatus => _status;

  @override
  SieGestureEngineMetrics get metrics => _metrics;

  @override
  SieGesturePolicy get policy => _evaluator.policy;

  void _emitStatus(SieGestureEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({SieGesturePolicy? policy}) async {
    _ensureNotDisposed();
    if (policy != null) {
      if (!policy.thresholds.isValid) {
        throw SieGestureEngineFailure(message: 'Invalid gesture thresholds');
      }
      _evaluator.setPolicy(policy);
    }
    _evaluator.reset();
    _metrics = const SieGestureEngineMetrics();
    _logger.info('engine_initialized', {'policy': _evaluator.policy.id.name});
    _emitStatus(
      _status.copyWith(
        health: SieGestureEngineHealth.healthy,
        initialized: true,
        running: false,
        activity: SieGestureActivity.none,
        policy: _evaluator.policy,
        clearPrimary: true,
        primaryPhase: SieGesturePhase.idle,
        lastEvent: 'initialized',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> start(
    Stream<SieConfidenceFrameSnapshot> confidenceSnapshots,
  ) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SieGestureEngineHealth.healthy,
        policy: _evaluator.policy,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = confidenceSnapshots.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
        for (final e in snap.events) {
          if (!_eventController.isClosed) {
            _eventController.add(e);
          }
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('confidence_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieGestureEngineHealth.error,
            lastError: SieGestureEngineFailure(message: e.toString(), cause: e),
            lastEvent: 'confidence_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieGestureFrameSnapshot process(SieConfidenceFrameSnapshot input) {
    final sw = Stopwatch()..start();
    try {
      final result = _evaluator.evaluate(input);
      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final snap = SieGestureFrameSnapshot(
        timestamp: result.snapshot.timestamp,
        frameSequence: result.snapshot.frameSequence,
        trackingState: result.snapshot.trackingState,
        activity: result.snapshot.activity,
        primaryKind: result.snapshot.primaryKind,
        primaryPhase: result.snapshot.primaryPhase,
        events: result.snapshot.events,
        processingMs: processingMs,
        policyId: result.snapshot.policyId,
        armingProgress: result.snapshot.armingProgress,
        dwellProgress: result.snapshot.dwellProgress,
        candidateKind: result.snapshot.candidateKind,
      );

      _noteProcessed(snap, result.conflicts, input.commitsSuppressed);
      _logSignificant(snap);
      _maybeUpdateStatus(snap);

      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieGestureEngineHealth.degraded,
          lastError: SieGestureEngineFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieGestureFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        trackingState: input.trackingState,
        activity: SieGestureActivity.none,
        primaryKind: null,
        primaryPhase: SieGesturePhase.idle,
        events: const [],
        processingMs: sw.elapsedMicroseconds / 1000.0,
        policyId: _evaluator.policy.id,
      );
    }
  }

  void _noteProcessed(
    SieGestureFrameSnapshot snap,
    int conflicts,
    bool commitsSuppressed,
  ) {
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    final avgProc = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    var commits = _metrics.commitsRecognized;
    var cancels = _metrics.cancelsRecognized;
    for (final e in snap.events) {
      if (e.kind == SieGestureKind.pinchCommit) commits++;
      if (e.kind == SieGestureKind.fistCancel) cancels++;
      _confidenceSamples.add(e.confidence);
      if (_confidenceSamples.length > 60) _confidenceSamples.removeAt(0);
    }
    final avgConf = _confidenceSamples.isEmpty
        ? 0.0
        : _confidenceSamples.reduce((a, b) => a + b) /
            _confidenceSamples.length;

    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      eventsEmitted: _metrics.eventsEmitted + snap.events.length,
      commitsRecognized: commits,
      cancelsRecognized: cancels,
      conflictsResolved: _metrics.conflictsResolved + conflicts,
      suppressedWhileRecovering: commitsSuppressed
          ? _metrics.suppressedWhileRecovering + 1
          : _metrics.suppressedWhileRecovering,
      averageProcessingMs: avgProc,
      lastProcessingMs: snap.processingMs,
      averageRecognitionConfidence: avgConf,
    );
  }

  void _logSignificant(SieGestureFrameSnapshot snap) {
    for (final e in snap.events) {
      if (e.phase == SieGesturePhase.cancelled ||
          e.kind == SieGestureKind.fistCancel) {
        _logger.info('gesture_cancelled', {
          'kind': e.kind.name,
          'phase': e.phase.name,
        });
      } else if (e.kind == SieGestureKind.pinchCommit ||
          e.kind == SieGestureKind.dwellSelect ||
          e.kind == SieGestureKind.swipeNavigation ||
          e.phase == SieGesturePhase.recognized ||
          e.phase == SieGesturePhase.committed) {
        _logger.info('gesture_recognized', {
          'kind': e.kind.name,
          'phase': e.phase.name,
          'confidence': e.confidence,
        });
      }
    }
    if (snap.candidateKind != null &&
        snap.primaryKind != null &&
        snap.candidateKind != snap.primaryKind) {
      _logger.info('gesture_conflict', {
        'winner': snap.primaryKind?.name,
        'candidate': snap.candidateKind?.name,
      });
    }
  }

  void _maybeUpdateStatus(SieGestureFrameSnapshot snap) {
    if (snap.activity != _status.activity ||
        snap.primaryKind != _status.primaryKind ||
        snap.primaryPhase != _status.primaryPhase) {
      _emitStatus(
        _status.copyWith(
          activity: snap.activity,
          primaryKind: snap.primaryKind,
          clearPrimary: snap.primaryKind == null,
          primaryPhase: snap.primaryPhase,
          policy: _evaluator.policy,
          health: SieGestureEngineHealth.healthy,
          lastEvent: 'gesture_state',
        ),
      );
    }
  }

  @override
  Future<void> setPolicy(SieGesturePolicy policy) async {
    _ensureNotDisposed();
    if (!policy.thresholds.isValid) {
      throw SieGestureEngineFailure(message: 'Invalid gesture policy');
    }
    _evaluator.setPolicy(policy);
    _logger.info('gesture_policy_changed', {
      'policy': policy.id.name,
      'swipe': policy.swipeNavigationEnabled,
      'dwell': policy.dwellSelectEnabled,
    });
    _emitStatus(
      _status.copyWith(
        policy: policy,
        lastEvent: 'policy_changed',
        clearError: true,
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
        health: SieGestureEngineHealth.healthy,
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
    _evaluator.reset();
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieGestureEngineHealth.disposed,
        running: false,
        initialized: false,
        activity: SieGestureActivity.none,
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
      throw SieGestureEngineFailure(message: 'Gesture engine is disposed.');
    }
  }
}
