import 'dart:async';

import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_confidence/logging/sie_confidence_logger.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_engine_status.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_snapshot.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_sources.dart';
import 'package:skillforge_sie/src/sie_confidence/ports/confidence_engine_port.dart';
import 'package:skillforge_sie/src/sie_confidence/processing/sie_confidence_evaluator.dart';
import 'package:skillforge_sie/src/sie_confidence/processing/sie_tracking_state_machine.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Production Confidence Engine — tracking reliability authority.
///
/// Does not classify gestures or drive the cursor.
final class SieConfidenceEngine implements ConfidenceEnginePort {
  /// Creates the engine.
  SieConfidenceEngine({
    SieConfidencePolicy policy = SieConfidencePolicy.standard,
    SieConfidenceLogger logger = const DeveloperSieConfidenceLogger(),
  })  : _logger = logger,
        _evaluator = SieConfidenceEvaluator(policy: policy);

  final SieConfidenceLogger _logger;
  final SieConfidenceEvaluator _evaluator;

  final StreamController<SieConfidenceEngineStatus> _statusController =
      StreamController<SieConfidenceEngineStatus>.broadcast();
  final StreamController<SieConfidenceFrameSnapshot> _snapshotController =
      StreamController<SieConfidenceFrameSnapshot>.broadcast();

  StreamSubscription<SieCalibratedFrameSnapshot>? _sub;
  SieConfidenceEngineStatus _status = SieConfidenceEngineStatus.idle();
  SieConfidenceEngineMetrics _metrics = const SieConfidenceEngineMetrics();
  final List<double> _confidenceSamples = [];
  final List<double> _stabilitySamples = [];
  final List<double> _processingSamples = [];
  bool _disposed = false;

  @override
  Stream<SieConfidenceEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieConfidenceFrameSnapshot> get snapshots =>
      _snapshotController.stream;

  @override
  SieConfidenceEngineStatus get currentStatus => _status;

  @override
  SieConfidenceEngineMetrics get metrics => _metrics;

  @override
  SieConfidencePolicy get policy => _evaluator.policy;

  void _emitStatus(SieConfidenceEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({SieConfidencePolicy? policy}) async {
    _ensureNotDisposed();
    if (policy != null) {
      if (!policy.thresholds.isValid) {
        throw SieConfidenceEngineFailure(
          message: 'Invalid confidence thresholds',
        );
      }
      _evaluator.setPolicy(policy);
    }
    _evaluator.reset();
    _metrics = const SieConfidenceEngineMetrics();
    _logger.info('engine_initialized', {'policy': _evaluator.policy.id.name});
    _emitStatus(
      _status.copyWith(
        health: SieConfidenceEngineHealth.healthy,
        initialized: true,
        running: false,
        trackingState: SieTrackingReliabilityState.idle,
        policy: _evaluator.policy,
        lastEvent: 'initialized',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> start(
    Stream<SieCalibratedFrameSnapshot> calibratedSnapshots,
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
        health: SieConfidenceEngineHealth.healthy,
        trackingState: _evaluator.trackingState,
        policy: _evaluator.policy,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = calibratedSnapshots.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('calibration_stream_error', null, e);
        _evaluator.setError();
        _emitStatus(
          _status.copyWith(
            health: SieConfidenceEngineHealth.error,
            trackingState: SieTrackingReliabilityState.error,
            lastError: SieConfidenceEngineFailure(
              message: e.toString(),
              cause: e,
            ),
            lastEvent: 'calibration_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieConfidenceFrameSnapshot process(SieCalibratedFrameSnapshot input) {
    final sw = Stopwatch()..start();
    try {
      final result = _evaluator.evaluate(input);
      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final snap = SieConfidenceFrameSnapshot(
        timestamp: result.snapshot.timestamp,
        frameSequence: result.snapshot.frameSequence,
        visionTrackingState: result.snapshot.visionTrackingState,
        trackingState: result.snapshot.trackingState,
        overallConfidence: result.snapshot.overallConfidence,
        sources: result.snapshot.sources,
        temporalStabilityScore: result.snapshot.temporalStabilityScore,
        frameValidation: result.snapshot.frameValidation,
        policyId: result.snapshot.policyId,
        recovery: result.snapshot.recovery,
        gestureReady: result.snapshot.gestureReady,
        mayConsume: result.snapshot.mayConsume,
        processingMs: processingMs,
        hands: result.snapshot.hands,
        profile: result.snapshot.profile,
        viewWidth: result.snapshot.viewWidth,
        viewHeight: result.snapshot.viewHeight,
        smoothedConfidence: result.snapshot.smoothedConfidence,
      );

      _noteProcessed(snap, result.step);
      _emitTransitionLogs(result.step);
      _maybeUpdateStatus(snap);

      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _evaluator.setError();
      _emitStatus(
        _status.copyWith(
          health: SieConfidenceEngineHealth.degraded,
          trackingState: SieTrackingReliabilityState.error,
          lastError: SieConfidenceEngineFailure(
            message: e.toString(),
            cause: e,
          ),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieConfidenceFrameSnapshot.rejected(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.visionTrackingState,
        trackingState: SieTrackingReliabilityState.error,
        policyId: _evaluator.policy.id,
        sources: SieConfidenceSources.zero,
        overallConfidence: 0,
        temporalStabilityScore: 0,
        recovery: SieRecoveryStatus.none,
        frameValidation: SieConfidenceFrameValidation.invalid,
        processingMs: sw.elapsedMicroseconds / 1000.0,
        profile: input.profile,
        viewWidth: input.viewWidth,
        viewHeight: input.viewHeight,
      );
    }
  }

  void _noteProcessed(
    SieConfidenceFrameSnapshot snap,
    SieTrackingStateStep step,
  ) {
    _confidenceSamples.add(snap.overallConfidence);
    if (_confidenceSamples.length > 60) _confidenceSamples.removeAt(0);
    _stabilitySamples.add(snap.temporalStabilityScore);
    if (_stabilitySamples.length > 60) _stabilitySamples.removeAt(0);
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);

    final avgConf = _confidenceSamples.reduce((a, b) => a + b) /
        _confidenceSamples.length;
    final avgStab = _stabilitySamples.reduce((a, b) => a + b) /
        _stabilitySamples.length;
    final avgProc = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    var rejected = _metrics.framesRejected;
    if (snap.frameValidation == SieConfidenceFrameValidation.invalid ||
        snap.frameValidation == SieConfidenceFrameValidation.unstable) {
      rejected++;
    }
    var lost = _metrics.lostTrackingCount;
    var recovery = _metrics.recoveryCount;
    var enters = _metrics.thresholdEnterEvents;
    var exits = _metrics.thresholdExitEvents;
    if (step.enteredLost) {
      lost++;
      exits++;
    }
    if (step.completedRecovery) {
      recovery++;
      enters++;
    }
    if (step.enteredTracking) {
      enters++;
    }

    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      framesRejected: rejected,
      lostTrackingCount: lost,
      recoveryCount: recovery,
      averageConfidence: avgConf,
      lastConfidence: snap.overallConfidence,
      averageStability: avgStab,
      averageProcessingMs: avgProc,
      lastProcessingMs: snap.processingMs,
      thresholdEnterEvents: enters,
      thresholdExitEvents: exits,
    );
  }

  void _emitTransitionLogs(SieTrackingStateStep step) {
    if (step.enteredTracking) {
      _logger.info('tracking_acquired', {
        'state': step.state.name,
      });
    }
    if (step.enteredLost) {
      _logger.info('tracking_lost');
    }
    if (step.completedRecovery) {
      _logger.info('recovery_completed');
    }
  }

  void _maybeUpdateStatus(SieConfidenceFrameSnapshot snap) {
    final health = switch (snap.trackingState) {
      SieTrackingReliabilityState.error => SieConfidenceEngineHealth.error,
      SieTrackingReliabilityState.degraded =>
        SieConfidenceEngineHealth.degraded,
      SieTrackingReliabilityState.lostTracking =>
        SieConfidenceEngineHealth.degraded,
      _ => SieConfidenceEngineHealth.healthy,
    };
    // Avoid flooding Riverpod — only emit on state / health change.
    if (snap.trackingState != _status.trackingState ||
        health != _status.health ||
        (snap.overallConfidence - _status.lastOverallConfidence).abs() > 0.15) {
      _emitStatus(
        _status.copyWith(
          health: health,
          trackingState: snap.trackingState,
          policy: _evaluator.policy,
          lastOverallConfidence: snap.overallConfidence,
          lastStabilityScore: snap.temporalStabilityScore,
          lastEvent: 'evaluated',
        ),
      );
    }
  }

  @override
  Future<void> setPolicy(SieConfidencePolicyId policyId) async {
    _ensureNotDisposed();
    final next = SieConfidencePolicy.fromId(policyId);
    if (!next.thresholds.isValid) {
      throw SieConfidenceEngineFailure(message: 'Invalid policy thresholds');
    }
    _evaluator.setPolicy(next);
    _logger.info('confidence_policy_changed', {'policy': policyId.name});
    _emitStatus(
      _status.copyWith(
        policy: next,
        lastEvent: 'policy_changed',
        clearError: true,
      ),
    );
  }

  @override
  void setEnabled(bool enabled) {
    _ensureNotDisposed();
    _evaluator.setEnabled(enabled);
    _emitStatus(
      _status.copyWith(
        trackingState: _evaluator.trackingState,
        lastEvent: enabled ? 'enabled' : 'disabled',
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
        health: SieConfidenceEngineHealth.healthy,
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
        health: SieConfidenceEngineHealth.disposed,
        running: false,
        initialized: false,
        trackingState: SieTrackingReliabilityState.disabled,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieConfidenceEngineFailure(
        message: 'Confidence engine is disposed.',
      );
    }
  }
}
