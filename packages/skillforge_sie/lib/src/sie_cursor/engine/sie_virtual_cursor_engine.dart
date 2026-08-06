import 'dart:async';
import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_cursor/logging/sie_cursor_logger.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_engine_status.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_cursor/ports/virtual_cursor_engine_port.dart';
import 'package:skillforge_sie/src/sie_cursor/processing/sie_cursor_evaluator.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';

/// Production Virtual Cursor Engine — cursor model only.
///
/// Does not generate PointerEvents, hit-test widgets, or execute UI actions.
final class SieVirtualCursorEngine implements VirtualCursorEnginePort {
  /// Creates the engine.
  SieVirtualCursorEngine({
    SieCursorEngineConfig config = const SieCursorEngineConfig(),
    SieCursorLogger logger = const DeveloperSieCursorLogger(),
  })  : _logger = logger,
        _evaluator = SieCursorEvaluator(config: config);

  final SieCursorLogger _logger;
  final SieCursorEvaluator _evaluator;

  final StreamController<SieCursorEngineStatus> _statusController =
      StreamController<SieCursorEngineStatus>.broadcast();
  final StreamController<SieCursorSnapshot> _snapshotController =
      StreamController<SieCursorSnapshot>.broadcast();

  StreamSubscription<SieIntentFrameSnapshot>? _sub;
  SieCursorEngineStatus _status = SieCursorEngineStatus.idle();
  SieCursorEngineMetrics _metrics = const SieCursorEngineMetrics();
  SieCursorSnapshot? _latest;
  final List<double> _processingSamples = [];
  final List<double> _velocitySamples = [];
  bool _disposed = false;
  SieCursorState? _prevState;
  bool? _prevVisible;

  @override
  Stream<SieCursorEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieCursorSnapshot> get snapshots => _snapshotController.stream;

  @override
  SieCursorEngineStatus get currentStatus => _status;

  @override
  SieCursorEngineMetrics get metrics => _metrics;

  @override
  SieCursorEngineConfig get config => _evaluator.config;

  @override
  SieCursorSnapshot? get latestSnapshot => _latest;

  void _emitStatus(SieCursorEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({SieCursorEngineConfig? config}) async {
    _ensureNotDisposed();
    if (config != null) {
      if (!config.motion.isValid || !config.bounds.isValid) {
        throw SieCursorEngineFailure(message: 'Invalid cursor configuration');
      }
      _evaluator.setConfig(config);
    }
    _evaluator.reset();
    _metrics = const SieCursorEngineMetrics();
    _latest = null;
    _prevState = null;
    _prevVisible = null;
    _logger.info('engine_initialized', {
      'theme': _evaluator.config.theme.name,
      'profile': _evaluator.config.motionProfile.name,
    });
    _emitStatus(
      SieCursorEngineStatus(
        health: SieCursorEngineHealth.healthy,
        initialized: true,
        running: false,
        state: SieCursorState.hidden,
        theme: _evaluator.config.theme,
        motionProfile: _evaluator.config.motionProfile,
        visible: false,
        lastEvent: 'initialized',
      ),
    );
  }

  @override
  Future<void> start(Stream<SieIntentFrameSnapshot> intentSnapshots) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SieCursorEngineHealth.healthy,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = intentSnapshots.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('intent_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieCursorEngineHealth.error,
            lastError: SieCursorEngineFailure(message: e.toString(), cause: e),
            lastEvent: 'intent_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieCursorSnapshot process(SieIntentFrameSnapshot input) {
    final sw = Stopwatch()..start();
    try {
      final result = _evaluator.evaluate(input);
      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final snap = SieCursorSnapshot(
        timestamp: result.snapshot.timestamp,
        frameSequence: result.snapshot.frameSequence,
        position: result.snapshot.position,
        rawPosition: result.snapshot.rawPosition,
        velocity: result.snapshot.velocity,
        direction: result.snapshot.direction,
        acceleration: result.snapshot.acceleration,
        state: result.snapshot.state,
        visibility: result.snapshot.visibility,
        opacity: result.snapshot.opacity,
        theme: result.snapshot.theme,
        interactionMode: result.snapshot.interactionMode,
        trackingState: result.snapshot.trackingState,
        hoverTargetId: result.snapshot.hoverTargetId,
        snapTargetId: result.snapshot.snapTargetId,
        snapped: result.snapshot.snapped,
        predictionOffset: result.snapshot.predictionOffset,
        smoothingAlpha: result.snapshot.smoothingAlpha,
        animationPhase: result.snapshot.animationPhase,
        processingMs: processingMs,
        metadata: result.snapshot.metadata,
      );
      _latest = snap;
      _noteProcessed(snap, result.clamped, result.snapped);
      _logSignificant(snap);
      _maybeUpdateStatus(snap);
      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieCursorEngineHealth.degraded,
          lastError: SieCursorEngineFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieCursorSnapshot.hidden(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        theme: _evaluator.config.theme,
      );
    }
  }

  void _noteProcessed(SieCursorSnapshot snap, bool clamped, bool snapped) {
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    final avgProc = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    final speed = math.sqrt(
      snap.velocity.x * snap.velocity.x + snap.velocity.y * snap.velocity.y,
    );
    _velocitySamples.add(speed);
    if (_velocitySamples.length > 60) _velocitySamples.removeAt(0);
    final avgVel = _velocitySamples.reduce((a, b) => a + b) /
        _velocitySamples.length;

    final pred = math.sqrt(
      snap.predictionOffset.x * snap.predictionOffset.x +
          snap.predictionOffset.y * snap.predictionOffset.y,
    );

    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      averageProcessingMs: avgProc,
      lastProcessingMs: snap.processingMs,
      averageVelocity: avgVel,
      lastPredictionPx: pred,
      lastSmoothingAlpha: snap.smoothingAlpha,
      snapEngagements:
          snapped ? _metrics.snapEngagements + 1 : _metrics.snapEngagements,
      clampEvents: clamped ? _metrics.clampEvents + 1 : _metrics.clampEvents,
    );
  }

  void _logSignificant(SieCursorSnapshot snap) {
    if (_prevState != snap.state) {
      if (snap.state == SieCursorState.lostTracking) {
        _logger.info('lost_tracking', {'frame': snap.frameSequence});
      } else if (snap.state == SieCursorState.recovering) {
        _logger.info('recovering', {'frame': snap.frameSequence});
      }
      _prevState = snap.state;
    }
    final vis = snap.isVisible;
    if (_prevVisible != vis) {
      _logger.info(vis ? 'cursor_shown' : 'cursor_hidden', {
        'state': snap.state.name,
        'opacity': snap.opacity,
      });
      _prevVisible = vis;
    }
  }

  void _maybeUpdateStatus(SieCursorSnapshot snap) {
    if (snap.state != _status.state ||
        snap.isVisible != _status.visible ||
        snap.theme != _status.theme) {
      _emitStatus(
        _status.copyWith(
          state: snap.state,
          visible: snap.isVisible,
          theme: snap.theme,
          motionProfile: _evaluator.config.motionProfile,
          health: SieCursorEngineHealth.healthy,
          lastEvent: 'cursor_state',
        ),
      );
    }
  }

  @override
  Future<void> setConfig(SieCursorEngineConfig config) async {
    _ensureNotDisposed();
    if (!config.motion.isValid) {
      throw SieCursorEngineFailure(message: 'Invalid cursor motion config');
    }
    _evaluator.setConfig(config);
    _logger.info('config_changed', {
      'theme': config.theme.name,
      'profile': config.motionProfile.name,
    });
    _emitStatus(
      _status.copyWith(
        theme: config.theme,
        motionProfile: config.motionProfile,
        lastEvent: 'config_changed',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> setDisplayBounds(SieCursorDisplayBounds bounds) async {
    _ensureNotDisposed();
    if (!bounds.isValid) {
      throw SieCursorEngineFailure(message: 'Invalid display bounds');
    }
    _evaluator.setConfig(_evaluator.config.copyWith(bounds: bounds));
    _logger.info('display_resized', {
      'w': bounds.width,
      'h': bounds.height,
      'dpr': bounds.devicePixelRatio,
    });
  }

  @override
  Future<void> setSnapTargets(List<SieCursorSnapTarget> targets) async {
    _ensureNotDisposed();
    _evaluator.setSnapTargets(targets);
  }

  @override
  Future<void> setTheme(SieCursorThemeId theme) async {
    _ensureNotDisposed();
    _evaluator.setConfig(_evaluator.config.copyWith(theme: theme));
    _logger.info('theme_changed', {'theme': theme.name});
    _emitStatus(
      _status.copyWith(theme: theme, lastEvent: 'theme_changed'),
    );
  }

  @override
  Future<void> setMotionProfile(SieCursorMotionProfileId profile) async {
    _ensureNotDisposed();
    final motion = SieCursorMotionConfig.forProfile(profile);
    _evaluator.setConfig(
      _evaluator.config.copyWith(
        motionProfile: profile,
        motion: motion,
      ),
    );
    _logger.info('motion_profile_changed', {'profile': profile.name});
    _emitStatus(
      _status.copyWith(
        motionProfile: profile,
        lastEvent: 'motion_profile_changed',
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
        health: SieCursorEngineHealth.healthy,
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
        health: SieCursorEngineHealth.disposed,
        running: false,
        initialized: false,
        state: SieCursorState.hidden,
        visible: false,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieCursorEngineFailure(message: 'Cursor engine is disposed.');
    }
  }
}
