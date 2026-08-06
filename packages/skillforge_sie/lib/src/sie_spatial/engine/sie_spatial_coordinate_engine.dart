import 'dart:async';

import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/logging/sie_spatial_logger.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_config.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_metrics.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_status.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_hand_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_landmark.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';
import 'package:skillforge_sie/src/sie_spatial/ports/spatial_coordinate_engine_port.dart';
import 'package:skillforge_sie/src/sie_spatial/processing/sie_spatial_transform_pipeline.dart';

/// Production Spatial Coordinate Engine — geometric transforms only.
///
/// Converts validated landmark snapshots into Flutter logical coordinates.
/// Does not interpret gestures or drive the cursor.
final class SieSpatialCoordinateEngine implements SpatialCoordinateEnginePort {
  /// Creates the engine.
  SieSpatialCoordinateEngine({
    SieSpatialEngineConfig config = SieSpatialEngineConfig.sieDefaults,
    SieViewportGeometry viewport = SieViewportGeometry.unset,
    SieSpatialLogger logger = const DeveloperSieSpatialLogger(),
  })  : _config = config,
        _viewport = viewport,
        _logger = logger,
        _pipeline = SieSpatialTransformPipeline(config);

  final SieSpatialLogger _logger;
  SieSpatialEngineConfig _config;
  SieViewportGeometry _viewport;
  SieSpatialTransformPipeline _pipeline;

  final StreamController<SieSpatialEngineStatus> _statusController =
      StreamController<SieSpatialEngineStatus>.broadcast();
  final StreamController<SieSpatialFrameSnapshot> _snapshotController =
      StreamController<SieSpatialFrameSnapshot>.broadcast();

  StreamSubscription<SieLandmarkFrameSnapshot>? _sub;
  SieSpatialEngineStatus _status = SieSpatialEngineStatus.idle();
  SieSpatialEngineMetrics _metrics = const SieSpatialEngineMetrics();
  final List<double> _processingSamples = [];
  bool _disposed = false;
  SieContentLayout? _cachedLayout;
  SieViewportGeometry? _layoutViewport;

  @override
  Stream<SieSpatialEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieSpatialFrameSnapshot> get snapshots => _snapshotController.stream;

  @override
  SieSpatialEngineStatus get currentStatus => _status;

  @override
  SieSpatialEngineMetrics get metrics => _metrics;

  @override
  SieSpatialEngineConfig get config => _config;

  @override
  SieViewportGeometry get viewport => _viewport;

  void _emitStatus(SieSpatialEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({
    SieSpatialEngineConfig? config,
    SieViewportGeometry? viewport,
  }) async {
    _ensureNotDisposed();
    if (config != null) {
      _config = config;
      _pipeline = SieSpatialTransformPipeline(_config);
      _cachedLayout = null;
    }
    if (viewport != null) {
      _applyViewport(viewport, log: false);
    }
    _metrics = const SieSpatialEngineMetrics();
    _logger.info('engine_initialized');
    _emitStatus(
      _status.copyWith(
        health: _viewport.isValid
            ? SieSpatialEngineHealth.healthy
            : SieSpatialEngineHealth.degraded,
        initialized: true,
        running: false,
        viewport: _viewport,
        lastEvent: 'initialized',
        clearError: true,
      ),
    );
  }

  @override
  void updateViewport(SieViewportGeometry viewport) {
    _ensureNotDisposed();
    _applyViewport(viewport, log: true);
    final health = viewport.isValid
        ? (_status.running
            ? SieSpatialEngineHealth.healthy
            : (_status.initialized
                ? SieSpatialEngineHealth.healthy
                : SieSpatialEngineHealth.idle))
        : SieSpatialEngineHealth.degraded;
    if (!viewport.isValid) {
      _logger.warn('mapping_error', {
        'reason': 'invalid_viewport',
        'viewWidth': viewport.viewWidth,
        'viewHeight': viewport.viewHeight,
      });
      _metrics = _metrics.copyWith(
        invalidViewportEvents: _metrics.invalidViewportEvents + 1,
      );
    }
    _emitStatus(
      _status.copyWith(
        health: health,
        viewport: _viewport,
        lastEvent: 'viewport_changed',
        clearError: viewport.isValid,
        lastError: viewport.isValid
            ? null
            : SieSpatialEngineFailure(message: 'Invalid viewport geometry'),
      ),
    );
  }

  void _applyViewport(SieViewportGeometry viewport, {required bool log}) {
    final orientationChanged = _viewport.orientation != viewport.orientation;
    final sizeChanged = _viewport.viewWidth != viewport.viewWidth ||
        _viewport.viewHeight != viewport.viewHeight ||
        _viewport.cameraAspectRatio != viewport.cameraAspectRatio ||
        _viewport.fitMode != viewport.fitMode ||
        _viewport.mirrorHorizontal != viewport.mirrorHorizontal ||
        _viewport.marginLeft != viewport.marginLeft ||
        _viewport.marginTop != viewport.marginTop ||
        _viewport.marginRight != viewport.marginRight ||
        _viewport.marginBottom != viewport.marginBottom ||
        _viewport.devicePixelRatio != viewport.devicePixelRatio;

    _viewport = viewport;
    _cachedLayout = null;
    _layoutViewport = null;

    if (sizeChanged) {
      _metrics = _metrics.copyWith(
        viewportUpdates: _metrics.viewportUpdates + 1,
      );
      if (log) {
        _logger.info('viewport_changed', {
          'w': viewport.viewWidth,
          'h': viewport.viewHeight,
          'aspect': viewport.cameraAspectRatio,
          'dpr': viewport.devicePixelRatio,
        });
      }
    }
    if (orientationChanged) {
      _metrics = _metrics.copyWith(
        orientationChanges: _metrics.orientationChanges + 1,
      );
      if (log) {
        _logger.info('orientation_changed', {
          'degrees': viewport.orientation.degrees,
        });
      }
    }
  }

  SieContentLayout? _layoutOrNull() {
    if (!_viewport.isValid) return null;
    if (_cachedLayout != null && identical(_layoutViewport, _viewport)) {
      return _cachedLayout;
    }
    // Equality-based cache when viewport replaced with equal instance.
    if (_cachedLayout != null &&
        _layoutViewport != null &&
        _layoutViewport == _viewport) {
      return _cachedLayout;
    }
    try {
      final layout = _pipeline.layout(_viewport);
      _cachedLayout = layout;
      _layoutViewport = _viewport;
      return layout;
    } on ArgumentError catch (e) {
      _logger.warn('mapping_error', {'reason': e.message});
      _metrics = _metrics.copyWith(
        invalidViewportEvents: _metrics.invalidViewportEvents + 1,
      );
      return null;
    }
  }

  @override
  Future<void> start(Stream<SieLandmarkFrameSnapshot> landmarkSnapshots) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: _viewport.isValid
            ? SieSpatialEngineHealth.healthy
            : SieSpatialEngineHealth.degraded,
        viewport: _viewport,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = landmarkSnapshots.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('landmark_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieSpatialEngineHealth.error,
            lastError: SieSpatialEngineFailure(
              message: e.toString(),
              cause: e,
            ),
            lastEvent: 'landmark_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieSpatialFrameSnapshot process(SieLandmarkFrameSnapshot input) {
    final sw = Stopwatch()..start();
    try {
      final layout = _layoutOrNull();
      if (layout == null) {
        final empty = SieSpatialFrameSnapshot.empty(
          timestamp: input.timestamp,
          frameSequence: input.frameSequence,
          visionTrackingState: input.visionTrackingState,
          viewport: _viewport,
          processingMs: sw.elapsedMicroseconds / 1000.0,
        );
        _noteProcessed(
          processingMs: empty.processingMs,
          landmarkCount: 0,
          outOfBounds: 0,
        );
        if (_status.health != SieSpatialEngineHealth.degraded &&
            _status.health != SieSpatialEngineHealth.error) {
          _emitStatus(
            _status.copyWith(
              health: SieSpatialEngineHealth.degraded,
              lastError: SieSpatialEngineFailure(
                message: 'Invalid viewport; spatial mapping skipped',
              ),
              lastEvent: 'invalid_viewport',
            ),
          );
        }
        return empty;
      }

      final hands = <SieSpatialHandSnapshot>[];
      var outOfBounds = 0;
      var landmarkCount = 0;

      for (final hand in input.usableHands) {
        final spatialLandmarks = <SieSpatialLandmark>[];
        for (final lm in hand.landmarks) {
          final t = _pipeline.transformPoint(
            cameraX: lm.x,
            cameraY: lm.y,
            viewport: _viewport,
            layout: layout,
          );
          if (t.outOfBounds) outOfBounds++;
          landmarkCount++;
          spatialLandmarks.add(
            SieSpatialLandmark(
              index: lm.index,
              camera: t.camera,
              normalized: t.normalized,
              viewport: t.viewport,
              screen: t.screen,
              flutter: t.flutter,
              outOfBounds: t.outOfBounds,
              z: lm.z,
              visibility: lm.visibility,
              presence: lm.presence,
            ),
          );
        }
        hands.add(
          SieSpatialHandSnapshot(
            handId: hand.handId,
            handedness: hand.handedness,
            handednessScore: hand.handednessScore,
            handConfidence: hand.handConfidence,
            landmarks: List.unmodifiable(spatialLandmarks),
          ),
        );
      }

      final processingMs = sw.elapsedMicroseconds / 1000.0;
      _noteProcessed(
        processingMs: processingMs,
        landmarkCount: landmarkCount,
        outOfBounds: outOfBounds,
      );

      if (_status.health == SieSpatialEngineHealth.degraded &&
          _viewport.isValid &&
          _status.running) {
        _emitStatus(
          _status.copyWith(
            health: SieSpatialEngineHealth.healthy,
            lastEvent: 'recovered',
            clearError: true,
          ),
        );
      }

      return SieSpatialFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.visionTrackingState,
        viewport: _viewport,
        hands: List.unmodifiable(hands),
        processingMs: processingMs,
        outOfBoundsCount: outOfBounds,
      );
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieSpatialEngineHealth.degraded,
          lastError: SieSpatialEngineFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieSpatialFrameSnapshot.empty(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.visionTrackingState,
        viewport: _viewport,
        processingMs: sw.elapsedMicroseconds / 1000.0,
      );
    }
  }

  void _noteProcessed({
    required double processingMs,
    required int landmarkCount,
    required int outOfBounds,
  }) {
    _processingSamples.add(processingMs);
    if (_processingSamples.length > 60) {
      _processingSamples.removeAt(0);
    }
    final avg = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;
    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      landmarksTransformed: _metrics.landmarksTransformed + landmarkCount,
      outOfBoundsCount: _metrics.outOfBoundsCount + outOfBounds,
      lastProcessingMs: processingMs,
      averageProcessingMs: avg,
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
        health: SieSpatialEngineHealth.healthy,
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
    _cachedLayout = null;
    _layoutViewport = null;
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieSpatialEngineHealth.disposed,
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
      throw SieSpatialEngineFailure(message: 'Spatial engine is disposed.');
    }
  }
}
