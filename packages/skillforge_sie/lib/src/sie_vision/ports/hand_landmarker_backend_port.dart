import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_detected_hand.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';

/// Raw backend detection output (pre tracking-state enrichment).
final class HandLandmarkerBackendResult {
  /// Creates a backend result.
  const HandLandmarkerBackendResult({
    required this.hands,
    required this.inferenceMs,
    this.frameSequence = 0,
  });

  /// Detected hands (may be empty).
  final List<SieDetectedHand> hands;

  /// Inference time in ms.
  final double inferenceMs;

  /// Optional frame sequence from live capture backends.
  final int frameSequence;
}

/// Callback for live (self-capturing) backends — Web VIDEO mode.
typedef HandLandmarkerLiveResultCallback = void Function(
  HandLandmarkerBackendResult result,
);

/// MediaPipe (or mock) hand landmarker backend.
///
/// Purpose: hide vendor SDKs from [VisionRuntimePort].
abstract interface class HandLandmarkerBackendPort {
  /// Backend identity.
  SieVisionBackendKind get kind;

  /// Whether this backend can run on the current platform.
  bool get isSupported;

  /// When true, [startLiveCapture] owns camera + inference (preferred on Web).
  bool get supportsLiveCapture;

  /// Load model / WASM / native libs.
  Future<void> initialize(SieVisionConfig config);

  /// Run detection on one camera frame (Android / tests).
  Future<HandLandmarkerBackendResult> detect(SieCameraFrame frame);

  /// Start self-owned live capture (Web VIDEO + getUserMedia).
  ///
  /// Default implementations throw — only Web MediaPipe implements this.
  Future<void> startLiveCapture(
    HandLandmarkerLiveResultCallback onResult, {
    SieVisionConfig? config,
  });

  /// Stop live capture without disposing the backend.
  Future<void> stopLiveCapture();

  /// Release native / JS resources.
  Future<void> dispose();
}
