import 'dart:async';

import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_landmarks/logging/sie_landmark_logger.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_hand_landmark_snapshot.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_config.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_metrics.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_status.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_enums.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_landmarks/ports/landmark_engine_port.dart';
import 'package:skillforge_sie/src/sie_landmarks/processing/sie_landmark_normalizer.dart';
import 'package:skillforge_sie/src/sie_landmarks/processing/sie_landmark_stabilizer.dart';
import 'package:skillforge_sie/src/sie_landmarks/processing/sie_landmark_validator.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_result.dart';

/// Production Landmark Engine — validate, normalize, stabilize Vision output.
///
/// Does not classify gestures or drive the cursor.
final class SieLandmarkEngine implements LandmarkEnginePort {
  /// Creates the engine.
  SieLandmarkEngine({
    SieLandmarkEngineConfig config = SieLandmarkEngineConfig.sieDefaults,
    SieLandmarkLogger logger = const DeveloperSieLandmarkLogger(),
  })  : _config = config,
        _logger = logger,
        _validator = SieLandmarkValidator(config),
        _normalizer = SieLandmarkNormalizer(config),
        _stabilizer = SieLandmarkStabilizer(config);

  final SieLandmarkLogger _logger;
  SieLandmarkEngineConfig _config;
  SieLandmarkValidator _validator;
  SieLandmarkNormalizer _normalizer;
  final SieLandmarkStabilizer _stabilizer;

  final StreamController<SieLandmarkEngineStatus> _statusController =
      StreamController<SieLandmarkEngineStatus>.broadcast();
  final StreamController<SieLandmarkFrameSnapshot> _snapshotController =
      StreamController<SieLandmarkFrameSnapshot>.broadcast();

  StreamSubscription<SieVisionResult>? _sub;
  SieLandmarkEngineStatus _status = SieLandmarkEngineStatus.idle();
  SieLandmarkEngineMetrics _metrics = const SieLandmarkEngineMetrics();
  final List<double> _processingSamples = [];
  final List<double> _deltaSamples = [];
  bool _disposed = false;
  int _rejectionStreak = 0;

  @override
  Stream<SieLandmarkEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieLandmarkFrameSnapshot> get snapshots => _snapshotController.stream;

  @override
  SieLandmarkEngineStatus get currentStatus => _status;

  @override
  SieLandmarkEngineMetrics get metrics => _metrics;

  @override
  SieLandmarkEngineConfig get config => _config;

  void _emitStatus(SieLandmarkEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({SieLandmarkEngineConfig? config}) async {
    _ensureNotDisposed();
    if (config != null) {
      _config = config;
      _validator = SieLandmarkValidator(_config);
      _normalizer = SieLandmarkNormalizer(_config);
      _stabilizer.config = _config;
    }
    _stabilizer.reset();
    _metrics = const SieLandmarkEngineMetrics();
    _rejectionStreak = 0;
    _logger.info('engine_initialized');
    _emitStatus(
      _status.copyWith(
        health: SieLandmarkEngineHealth.healthy,
        initialized: true,
        running: false,
        lastEvent: 'initialized',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> start(Stream<SieVisionResult> visionResults) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SieLandmarkEngineHealth.healthy,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = visionResults.listen(
      (result) {
        final snap = process(result);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('vision_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieLandmarkEngineHealth.error,
            lastError: SieLandmarkEngineFailure(
              message: e.toString(),
              cause: e,
            ),
            lastEvent: 'vision_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieLandmarkFrameSnapshot process(SieVisionResult input) {
    final sw = Stopwatch()..start();
    try {
      if (input.hands.isEmpty) {
        _stabilizer.reset();
        final empty = SieLandmarkFrameSnapshot.empty(
          timestamp: input.timestamp,
          frameSequence: input.frameSequence,
          visionTrackingState: input.trackingState,
          processingMs: sw.elapsedMicroseconds / 1000.0,
          visionInferenceMs: input.inferenceMs,
        );
        _noteEmpty(empty.processingMs);
        return empty;
      }

      final handSnaps = <SieHandLandmarkSnapshot>[];
      final activeIds = <int>[];
      var anyRejected = false;
      var anyDegraded = false;
      var anyValid = false;
      var deltaAcc = 0.0;
      var deltaN = 0;

      for (final hand in input.hands) {
        final handId = hand.index;
        final validation = _validator.validateHand(hand);
        if (!validation.isValid) {
          anyRejected = true;
          _rejectionStreak++;
          _logger.warn('validation_failure', {
            'reason': validation.reason?.name,
            'handId': handId,
            'count': hand.landmarks.length,
          });
          handSnaps.add(
            SieHandLandmarkSnapshot.rejected(
              handId: handId,
              handedness: hand.handedness,
              handednessScore: hand.handednessScore,
              handConfidence: hand.handConfidence,
              reason: validation.reason ?? SieLandmarkRejectionReason.anomaly,
            ),
          );
          _metrics = _metrics.copyWith(
            handsRejected: _metrics.handsRejected + 1,
          );
          continue;
        }

        final norm = _normalizer.normalize(hand.landmarks);
        final stab = _stabilizer.stabilize(
          handId: handId,
          current: norm.landmarks,
        );
        activeIds.add(handId);
        deltaAcc += stab.meanDelta;
        deltaN++;

        final state = norm.wasClamped
            ? SieLandmarkValidationState.degraded
            : SieLandmarkValidationState.valid;
        if (state == SieLandmarkValidationState.degraded) {
          anyDegraded = true;
          _metrics = _metrics.copyWith(
            handsDegraded: _metrics.handsDegraded + 1,
          );
        } else {
          anyValid = true;
          _metrics = _metrics.copyWith(
            handsAccepted: _metrics.handsAccepted + 1,
          );
        }
        _rejectionStreak = 0;

        handSnaps.add(
          SieHandLandmarkSnapshot(
            handId: handId,
            handedness: hand.handedness,
            handednessScore: hand.handednessScore,
            handConfidence: hand.handConfidence,
            landmarks: stab.landmarks,
            validationState: state,
            wasStabilized: stab.applied,
            wasClamped: norm.wasClamped,
          ),
        );
      }

      _stabilizer.retainHands(activeIds);

      final frameState = _aggregateFrameState(
        anyValid: anyValid,
        anyDegraded: anyDegraded,
        anyRejected: anyRejected,
        usableCount: handSnaps.where((h) => h.isUsable).length,
      );

      final processingMs = sw.elapsedMicroseconds / 1000.0;
      _noteProcessed(
        processingMs: processingMs,
        meanDelta: deltaN == 0 ? 0 : deltaAcc / deltaN,
      );
      _updateHealthFromRejections();

      return SieLandmarkFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.trackingState,
        hands: List.unmodifiable(handSnaps),
        validationState: frameState,
        processingMs: processingMs,
        visionInferenceMs: input.inferenceMs,
      );
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieLandmarkEngineHealth.degraded,
          lastError: SieLandmarkEngineFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieLandmarkFrameSnapshot.empty(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.trackingState,
        processingMs: sw.elapsedMicroseconds / 1000.0,
        visionInferenceMs: input.inferenceMs,
      );
    }
  }

  static SieLandmarkValidationState _aggregateFrameState({
    required bool anyValid,
    required bool anyDegraded,
    required bool anyRejected,
    required int usableCount,
  }) {
    if (usableCount == 0) {
      return anyRejected
          ? SieLandmarkValidationState.rejected
          : SieLandmarkValidationState.empty;
    }
    if (anyDegraded && !anyValid) {
      return SieLandmarkValidationState.degraded;
    }
    if (anyDegraded) return SieLandmarkValidationState.degraded;
    return SieLandmarkValidationState.valid;
  }

  void _noteEmpty(double processingMs) {
    _noteProcessed(processingMs: processingMs, meanDelta: 0);
    _metrics = _metrics.copyWith(framesEmpty: _metrics.framesEmpty + 1);
  }

  void _noteProcessed({required double processingMs, required double meanDelta}) {
    _processingSamples.add(processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    if (meanDelta > 0) {
      _deltaSamples.add(meanDelta);
      if (_deltaSamples.length > 60) _deltaSamples.removeAt(0);
    }
    final accepted = _metrics.handsAccepted + _metrics.handsDegraded;
    final rejected = _metrics.handsRejected;
    final total = accepted + rejected;
    final success = total == 0 ? 1.0 : accepted / total;
    final avgDelta = _deltaSamples.isEmpty
        ? 0.0
        : _deltaSamples.reduce((a, b) => a + b) / _deltaSamples.length;
    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      lastProcessingMs: processingMs,
      averageProcessingMs: _processingSamples.reduce((a, b) => a + b) /
          _processingSamples.length,
      validationSuccessRate: success,
      stabilityScore: SieLandmarkStabilizer.stabilityScoreFromDelta(avgDelta),
    );
  }

  void _updateHealthFromRejections() {
    if (!_status.running) return;
    if (_rejectionStreak >= 10) {
      if (_status.health != SieLandmarkEngineHealth.degraded) {
        _logger.warn('recovery_elevated_rejections', {'streak': _rejectionStreak});
        _emitStatus(
          _status.copyWith(
            health: SieLandmarkEngineHealth.degraded,
            lastEvent: 'elevated_rejections',
          ),
        );
      }
    } else if (_status.health == SieLandmarkEngineHealth.degraded &&
        _rejectionStreak == 0) {
      _logger.info('recovery_events');
      _emitStatus(
        _status.copyWith(
          health: SieLandmarkEngineHealth.healthy,
          lastEvent: 'recovered',
          clearError: true,
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _sub?.cancel();
    _sub = null;
    _stabilizer.reset();
    _logger.info('engine_stopped');
    _emitStatus(
      _status.copyWith(
        running: false,
        health: SieLandmarkEngineHealth.healthy,
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
    _stabilizer.reset();
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieLandmarkEngineHealth.disposed,
        running: false,
        initialized: false,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieLandmarkEngineFailure(message: 'Landmark engine is disposed.');
    }
  }
}
