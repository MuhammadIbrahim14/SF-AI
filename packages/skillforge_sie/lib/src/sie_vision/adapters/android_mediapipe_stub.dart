import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';

/// Stub factory piece for non-Android builds.
HandLandmarkerBackendPort createAndroidMediaPipeHandLandmarkerBackend() {
  throw UnsupportedError('Android MediaPipe backend requires dart.library.io');
}
