import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_detected_hand.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_hand_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';

/// Deterministic mock Hand Landmarker for tests and CI (no MediaPipe).
final class MockHandLandmarkerBackend implements HandLandmarkerBackendPort {
  /// Creates a mock backend.
  MockHandLandmarkerBackend({
    this.handsToReturn = const [],
    this.inferenceMs = 4,
    this.failOnInit = false,
    this.failOnDetect = false,
  });

  /// Hands returned by each [detect] call.
  List<SieDetectedHand> handsToReturn;

  /// Simulated inference duration.
  double inferenceMs;

  /// When true, [initialize] throws.
  bool failOnInit;

  /// When true, [detect] throws.
  bool failOnDetect;

  bool _initialized = false;

  @override
  SieVisionBackendKind get kind => SieVisionBackendKind.mock;

  @override
  bool get isSupported => true;

  @override
  bool get supportsLiveCapture => false;

  @override
  Future<void> initialize(SieVisionConfig config) async {
    if (failOnInit) {
      throw StateError('Mock init failure');
    }
    _initialized = true;
  }

  @override
  Future<HandLandmarkerBackendResult> detect(SieCameraFrame frame) async {
    if (!_initialized) {
      throw StateError('Mock backend not initialized');
    }
    if (failOnDetect) {
      throw StateError('Mock detect failure');
    }
    return HandLandmarkerBackendResult(
      hands: List<SieDetectedHand>.unmodifiable(handsToReturn),
      inferenceMs: inferenceMs,
    );
  }

  @override
  Future<void> startLiveCapture(
    HandLandmarkerLiveResultCallback onResult, {
    SieVisionConfig? config,
  }) async {
    throw UnsupportedError('Mock backend does not support live capture');
  }

  @override
  Future<void> stopLiveCapture() async {}

  @override
  Future<void> dispose() async {
    _initialized = false;
  }

  /// Builds a full 21-point synthetic hand (normalized).
  static SieDetectedHand syntheticHand({
    SieHandedness handedness = SieHandedness.right,
    double confidence = 0.9,
    double tipX = 0.5,
    double tipY = 0.4,
  }) {
    final landmarks = List<SieHandLandmark>.generate(21, (i) {
      if (i == 8) {
        return SieHandLandmark(x: tipX, y: tipY, z: 0);
      }
      return SieHandLandmark(x: 0.5, y: 0.5 + i * 0.001, z: 0);
    });
    return SieDetectedHand(
      landmarks: landmarks,
      handedness: handedness,
      handednessScore: confidence,
      handConfidence: confidence,
    );
  }
}
