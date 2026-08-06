import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/default_platform_detector.dart';
import 'package:skillforge_sie/src/sie_vision/adapters/android_mediapipe_stub.dart'
    if (dart.library.io) 'package:skillforge_sie/src/sie_vision/adapters/android_mediapipe_hand_landmarker.dart'
    as android_mp;
import 'package:skillforge_sie/src/sie_vision/adapters/unsupported_hand_landmarker_backend.dart';
import 'package:skillforge_sie/src/sie_vision/adapters/web_mediapipe_stub.dart'
    if (dart.library.html) 'package:skillforge_sie/src/sie_vision/adapters/web_mediapipe_hand_landmarker.dart'
    as web_mp;
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';

/// Creates the default MediaPipe (or unsupported) hand landmarker backend.
HandLandmarkerBackendPort createDefaultHandLandmarkerBackend({
  SiePlatformKind? platform,
}) {
  final kind = platform ?? const DefaultPlatformDetector().detect();
  switch (kind) {
    case SiePlatformKind.web:
      return web_mp.createWebMediaPipeHandLandmarkerBackend();
    case SiePlatformKind.android:
      return android_mp.createAndroidMediaPipeHandLandmarkerBackend();
    case SiePlatformKind.ios:
    case SiePlatformKind.windows:
    case SiePlatformKind.linux:
    case SiePlatformKind.macos:
    case SiePlatformKind.unsupported:
      return UnsupportedHandLandmarkerBackend(kind);
  }
}
