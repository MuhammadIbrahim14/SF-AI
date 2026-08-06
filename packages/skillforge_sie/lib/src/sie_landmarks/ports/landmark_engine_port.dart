import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_config.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_metrics.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_status.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_result.dart';

/// Landmark Engine port — trusted snapshots for Spatial Coordinate Engine.
///
/// Purpose: validate / normalize / stabilize Vision Provider output.
/// Inputs: [SieVisionResult] stream only.
/// Outputs: immutable [SieLandmarkFrameSnapshot] stream (not Riverpod).
/// Failure behavior: reject bad hands; empty frames are valid-empty.
abstract interface class LandmarkEnginePort {
  /// Low-frequency status (Riverpod-safe).
  Stream<SieLandmarkEngineStatus> get status;

  /// High-frequency snapshots — **not** for Riverpod (ADR-008).
  Stream<SieLandmarkFrameSnapshot> get snapshots;

  /// Latest status.
  SieLandmarkEngineStatus get currentStatus;

  /// Latest metrics.
  SieLandmarkEngineMetrics get metrics;

  /// Active config.
  SieLandmarkEngineConfig get config;

  /// Prepare engine.
  Future<void> initialize({SieLandmarkEngineConfig? config});

  /// Attach to Vision Provider results.
  Future<void> start(Stream<SieVisionResult> visionResults);

  /// Detach from vision stream.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous process for tests / replay (does not require [start]).
  SieLandmarkFrameSnapshot process(SieVisionResult input);
}
