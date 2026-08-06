import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';

/// Backend used when MediaPipe is not wired for the OS.
final class UnsupportedHandLandmarkerBackend
    implements HandLandmarkerBackendPort {
  /// Creates an unsupported backend.
  UnsupportedHandLandmarkerBackend(this.platform);

  /// Platform this backend represents.
  final SiePlatformKind platform;

  @override
  SieVisionBackendKind get kind => SieVisionBackendKind.unsupported;

  @override
  bool get isSupported => false;

  @override
  bool get supportsLiveCapture => false;

  @override
  Future<void> initialize(SieVisionConfig config) async {
    throw SieVisionInitFailure(
      message:
          'MediaPipe Hand Landmarker is not available on ${platform.displayName}.',
    );
  }

  @override
  Future<HandLandmarkerBackendResult> detect(SieCameraFrame frame) async {
    throw SieVisionFailure(
      code: 'sie.vision.unsupported',
      message: 'Vision detect called on unsupported backend.',
    );
  }

  @override
  Future<void> startLiveCapture(
    HandLandmarkerLiveResultCallback onResult, {
    SieVisionConfig? config,
  }) async {
    throw SieVisionFailure(
      code: 'sie.vision.unsupported',
      message: 'Live capture not available on ${platform.displayName}.',
    );
  }

  @override
  Future<void> stopLiveCapture() async {}

  @override
  Future<void> dispose() async {}
}
