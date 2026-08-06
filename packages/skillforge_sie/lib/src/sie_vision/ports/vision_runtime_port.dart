import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_metrics.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_result.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_status.dart';

/// Stable Vision Runtime port (Document 04) — MediaPipe hidden behind this.
///
/// Purpose: consume [SieCameraFrame]s and emit [SieVisionResult]s.
/// Inputs: frame stream from Camera Engine only.
/// Outputs: [results] stream + low-frequency [status]/metrics].
/// Failure behavior: typed [SieFailure] via status / thrown on init; no gestures.
abstract interface class VisionRuntimePort {
  /// Low-frequency status (Riverpod-safe).
  Stream<SieVisionStatus> get status;

  /// High-frequency landmark results — **not** for Riverpod (ADR-008).
  Stream<SieVisionResult> get results;

  /// Latest status.
  SieVisionStatus get currentStatus;

  /// Latest metrics snapshot.
  SieVisionMetrics get metrics;

  /// Active config.
  SieVisionConfig get config;

  /// Backend identity.
  SieVisionBackendKind get backendKind;

  /// Load model / native runtime.
  Future<void> initialize({SieVisionConfig? config});

  /// Attach to Camera Engine frames and begin inference.
  Future<void> start(Stream<SieCameraFrame> frameSource);

  /// Stop consuming frames; keep backend warm when possible.
  Future<void> stop();

  /// Release all resources.
  Future<void> dispose();
}
