import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_config.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_metrics.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_status.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';

/// Spatial Coordinate Engine port — canonical Flutter coordinates.
///
/// Purpose: geometric transforms only (no gestures / cursor).
/// Inputs: [SieLandmarkFrameSnapshot] stream from Landmark Engine.
/// Outputs: immutable [SieSpatialFrameSnapshot] stream (not Riverpod).
abstract interface class SpatialCoordinateEnginePort {
  /// Low-frequency status.
  Stream<SieSpatialEngineStatus> get status;

  /// High-frequency spatial snapshots — **not** Riverpod (ADR-008).
  Stream<SieSpatialFrameSnapshot> get snapshots;

  /// Latest status.
  SieSpatialEngineStatus get currentStatus;

  /// Latest metrics.
  SieSpatialEngineMetrics get metrics;

  /// Active config.
  SieSpatialEngineConfig get config;

  /// Current viewport.
  SieViewportGeometry get viewport;

  /// Prepare engine with optional viewport.
  Future<void> initialize({
    SieSpatialEngineConfig? config,
    SieViewportGeometry? viewport,
  });

  /// Update viewport (resize / orientation / aspect).
  void updateViewport(SieViewportGeometry viewport);

  /// Attach to Landmark Engine snapshots.
  Future<void> start(Stream<SieLandmarkFrameSnapshot> landmarkSnapshots);

  /// Detach.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous transform for tests / replay.
  SieSpatialFrameSnapshot process(SieLandmarkFrameSnapshot input);
}
