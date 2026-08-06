import 'dart:async';

import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_vision/engine/sie_vision_stream_manager.dart';
import 'package:skillforge_sie/src/sie_vision/logging/sie_vision_logger.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_metrics.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_result.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_status.dart';
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';
import 'package:skillforge_sie/src/sie_vision/ports/vision_runtime_port.dart';

/// Production Vision Provider — Camera frames in, landmark results out.
///
/// Hides MediaPipe behind [HandLandmarkerBackendPort]. Never interprets
/// gestures or drives the cursor.
final class SieVisionProvider implements VisionRuntimePort {
  /// Creates the provider.
  SieVisionProvider({
    required HandLandmarkerBackendPort backend,
    SieVisionConfig config = SieVisionConfig.sieDefaults,
    SieVisionLogger logger = const DeveloperSieVisionLogger(),
  })  : _backend = backend,
        _config = config,
        _logger = logger;

  final HandLandmarkerBackendPort _backend;
  final SieVisionLogger _logger;
  final SieVisionStreamManager _results = SieVisionStreamManager();
  final StreamController<SieVisionStatus> _statusController =
      StreamController<SieVisionStatus>.broadcast();

  SieVisionConfig _config;
  SieVisionStatus _status = SieVisionStatus.idle();
  SieVisionMetrics _metrics = const SieVisionMetrics();
  StreamSubscription<SieCameraFrame>? _frameSub;
  bool _busy = false;
  bool _disposed = false;
  DateTime? _lastHandAt;
  final List<DateTime> _inferMarks = [];
  final List<DateTime> _resultMarks = [];
  final List<double> _inferSamples = [];

  @override
  Stream<SieVisionStatus> get status => _statusController.stream;

  @override
  Stream<SieVisionResult> get results => _results.stream;

  @override
  SieVisionStatus get currentStatus => _status;

  @override
  SieVisionMetrics get metrics => _metrics;

  @override
  SieVisionConfig get config => _config;

  @override
  SieVisionBackendKind get backendKind => _backend.kind;

  void _emitStatus(SieVisionStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({SieVisionConfig? config}) async {
    _ensureNotDisposed();
    if (config != null) _config = config;
    if (!_backend.isSupported) {
      final failure = SieVisionInitFailure(
        message: 'Vision backend ${_backend.kind.name} is not supported here.',
      );
      _emitStatus(
        _status.copyWith(
          trackingState: SieVisionTrackingState.error,
          backend: _backend.kind,
          lastError: failure,
          lastEvent: 'init_unsupported',
        ),
      );
      throw failure;
    }
    _emitStatus(
      _status.copyWith(
        trackingState: SieVisionTrackingState.initializing,
        backend: _backend.kind,
        lastEvent: 'init_start',
        clearError: true,
      ),
    );
    _logger.info('backend_init_start', {'backend': _backend.kind.name});
    try {
      await _backend.initialize(_config);
      _emitStatus(
        _status.copyWith(
          trackingState: SieVisionTrackingState.ready,
          backend: _backend.kind,
          initialized: true,
          running: false,
          lastEvent: 'init_ok',
          clearError: true,
        ),
      );
      _logger.info('backend_initialized', {'backend': _backend.kind.name});
      _logger.info('model_loaded');
    } catch (e) {
      final failure = e is SieFailure
          ? e
          : SieVisionInitFailure(message: e.toString(), cause: e);
      _logger.error('backend_init_failed', null, e);
      _emitStatus(
        _status.copyWith(
          trackingState: SieVisionTrackingState.error,
          initialized: false,
          lastError: failure,
          lastEvent: 'init_failed',
        ),
      );
      throw failure;
    }
  }

  @override
  Future<void> start(Stream<SieCameraFrame> frameSource) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _frameSub?.cancel();
    await _backend.stopLiveCapture();
    _busy = false;
    _lastHandAt = null;
    _metrics = const SieVisionMetrics();
    _logger.info('detection_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        trackingState: SieVisionTrackingState.searching,
        lastEvent: 'detection_started',
        clearError: true,
      ),
    );

    // Web: VIDEO + getUserMedia inside MediaPipe bridge (camera image streams
    // are unreliable / unimplemented on Flutter Web).
    if (_backend.supportsLiveCapture) {
      try {
        await _backend.startLiveCapture(
          _onLiveResult,
          config: _config,
        );
      } catch (e) {
        _emitStatus(
          _status.copyWith(
            running: false,
            trackingState: SieVisionTrackingState.error,
            lastError: SieVisionFailure(
              code: 'sie.vision.live_capture',
              message: e.toString(),
              cause: e,
            ),
            lastEvent: 'live_capture_failed',
          ),
        );
        rethrow;
      }
      return;
    }

    _frameSub = frameSource.listen(
      _onFrame,
      onError: (Object e, StackTrace st) {
        _logger.error('frame_source_error', null, e);
        _emitStatus(
          _status.copyWith(
            trackingState: SieVisionTrackingState.error,
            lastError: SieVisionFailure(
              code: 'sie.vision.frame_source',
              message: e.toString(),
              cause: e,
            ),
            lastEvent: 'frame_source_error',
          ),
        );
      },
    );
  }

  void _onLiveResult(HandLandmarkerBackendResult raw) {
    if (_disposed || !_status.running) return;
    assert(() {
      if (raw.frameSequence <= 1 || raw.frameSequence % 60 == 0) {
        _logger.info('live_frame', {
          'seq': raw.frameSequence,
          'hands': raw.hands.length,
          'ms': raw.inferenceMs,
        });
      }
      return true;
    }());
    _publishInference(
      raw,
      frameSequence: raw.frameSequence,
    );
  }

  Future<void> _onFrame(SieCameraFrame frame) async {
    if (_disposed || !_status.running) return;
    _metrics = _metrics.copyWith(framesReceived: _metrics.framesReceived + 1);

    // Back-pressure: skip stale frames while inference is in flight.
    if (_busy) {
      _metrics = _metrics.copyWith(framesDropped: _metrics.framesDropped + 1);
      return;
    }
    _busy = true;
    try {
      final raw = await _backend.detect(frame);
      _publishInference(raw, frameSequence: frame.sequence);
    } catch (e) {
      _logger.error('detect_failed', {'seq': frame.sequence}, e);
      _emitStatus(
        _status.copyWith(
          lastError: SieVisionFailure(
            code: 'sie.vision.detect',
            message: e.toString(),
            cause: e,
          ),
          lastEvent: 'detect_failed',
        ),
      );
      _results.publish(
        SieVisionResult.none(
          timestamp: DateTime.now(),
          frameSequence: frame.sequence,
          trackingState: _status.trackingState,
          inferenceMs: 0,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  void _publishInference(
    HandLandmarkerBackendResult raw, {
    required int frameSequence,
  }) {
    _metrics = _metrics.copyWith(framesReceived: _metrics.framesReceived + 1);
    _noteInference(raw.inferenceMs);
    final tracking = _resolveTracking(raw.hands.isNotEmpty);
    final confidence =
        raw.hands.isEmpty ? 0.0 : raw.hands.first.handConfidence;
    if (raw.hands.isEmpty) {
      _metrics = _metrics.copyWith(noHandCount: _metrics.noHandCount + 1);
    }
    _metrics = _metrics.copyWith(
      framesInferred: _metrics.framesInferred + 1,
      lastInferenceMs: raw.inferenceMs,
      lastConfidence: confidence,
      averageInferenceMs: _avgInfer(),
      inferenceFps: _fps(_inferMarks),
      detectionFps: _fps(_resultMarks),
    );
    final result = SieVisionResult(
      timestamp: DateTime.now(),
      frameSequence: frameSequence,
      hands: raw.hands,
      trackingState: tracking,
      inferenceMs: raw.inferenceMs,
      detected: raw.hands.isNotEmpty,
    );
    _resultMarks.add(DateTime.now());
    _prune(_resultMarks);
    _results.publish(result);
    if (_status.trackingState != tracking) {
      _emitStatus(
        _status.copyWith(trackingState: tracking, lastEvent: tracking.name),
      );
    }
  }

  SieVisionTrackingState _resolveTracking(bool hasHand) {
    final now = DateTime.now();
    if (hasHand) {
      _lastHandAt = now;
      return SieVisionTrackingState.tracking;
    }
    if (_lastHandAt == null) {
      return SieVisionTrackingState.searching;
    }
    final absent = now.difference(_lastHandAt!).inMilliseconds;
    if (absent <= _config.recoveringTimeoutMs) {
      return SieVisionTrackingState.tracking;
    }
    if (absent <= _config.lostTimeoutMs) {
      return SieVisionTrackingState.recovering;
    }
    return SieVisionTrackingState.lost;
  }

  void _noteInference(double ms) {
    final now = DateTime.now();
    _inferMarks.add(now);
    _prune(_inferMarks);
    _inferSamples.add(ms);
    if (_inferSamples.length > 60) {
      _inferSamples.removeAt(0);
    }
  }

  double _avgInfer() {
    if (_inferSamples.isEmpty) return 0;
    return _inferSamples.reduce((a, b) => a + b) / _inferSamples.length;
  }

  static double _fps(List<DateTime> marks) => marks.length.toDouble();

  static void _prune(List<DateTime> marks) {
    final now = DateTime.now();
    marks.removeWhere((t) => now.difference(t).inMilliseconds > 1000);
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    _logger.info('detection_stopped');
    await _frameSub?.cancel();
    _frameSub = null;
    await _backend.stopLiveCapture();
    _busy = false;
    _emitStatus(
      _status.copyWith(
        running: false,
        trackingState: SieVisionTrackingState.ready,
        lastEvent: 'detection_stopped',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _logger.info('backend_shutdown');
    _disposed = true;
    await _frameSub?.cancel();
    _frameSub = null;
    try {
      await _backend.stopLiveCapture();
      await _backend.dispose();
    } catch (_) {}
    await _results.dispose();
    _emitStatus(
      _status.copyWith(
        trackingState: SieVisionTrackingState.disposed,
        running: false,
        initialized: false,
        lastEvent: 'disposed',
      ),
    );
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieVisionFailure(
        code: 'sie.vision.disposed',
        message: 'Vision provider is disposed.',
      );
    }
  }
}
