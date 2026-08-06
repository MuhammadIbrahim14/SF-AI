import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_detected_hand.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_hand_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';

/// Android MediaPipe Hand Landmarker via `hand_landmarker` (JNI, off UI thread).
HandLandmarkerBackendPort createAndroidMediaPipeHandLandmarkerBackend() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError('Android MediaPipe backend only runs on Android');
  }
  return AndroidMediaPipeHandLandmarkerBackend();
}

/// Production Android adapter — never imported on web.
final class AndroidMediaPipeHandLandmarkerBackend
    implements HandLandmarkerBackendPort {
  HandLandmarkerPlugin? _plugin;
  StreamSubscription<List<Hand>>? _sub;
  Completer<HandLandmarkerBackendResult>? _waiter;
  DateTime? _inferStarted;

  @override
  SieVisionBackendKind get kind => SieVisionBackendKind.mediaPipeHandLandmarker;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get supportsLiveCapture => false;

  @override
  Future<void> initialize(SieVisionConfig config) async {
    await dispose();
    try {
      _plugin = HandLandmarkerPlugin.create(
        numHands: config.numHands,
        minHandDetectionConfidence: config.minHandDetectionConfidence,
        delegate: HandLandmarkerDelegate.gpu,
      );
      _sub = _plugin!.landmarkStream.listen(_onLandmarks);
    } catch (e) {
      throw SieVisionInitFailure(
        message: 'Failed to create MediaPipe Hand Landmarker: $e',
        cause: e,
      );
    }
  }

  void _onLandmarks(List<Hand> hands) {
    final waiter = _waiter;
    if (waiter == null || waiter.isCompleted) return;
    final ms = _inferStarted == null
        ? 0.0
        : DateTime.now().difference(_inferStarted!).inMicroseconds / 1000.0;
    waiter.complete(
      HandLandmarkerBackendResult(hands: _mapHands(hands), inferenceMs: ms),
    );
    _waiter = null;
    _inferStarted = null;
  }

  @override
  Future<HandLandmarkerBackendResult> detect(SieCameraFrame frame) async {
    final plugin = _plugin;
    if (plugin == null) {
      throw SieVisionFailure(
        code: 'sie.vision.not_initialized',
        message: 'Android MediaPipe backend is not initialized.',
      );
    }
    final image = frame.platformImage;
    if (image is! CameraImage) {
      return const HandLandmarkerBackendResult(hands: [], inferenceMs: 0);
    }

    // Drop if a previous detect is still waiting (back-pressure at backend).
    if (_waiter != null && !_waiter!.isCompleted) {
      return const HandLandmarkerBackendResult(hands: [], inferenceMs: 0);
    }

    final completer = Completer<HandLandmarkerBackendResult>();
    _waiter = completer;
    _inferStarted = DateTime.now();
    try {
      plugin.processFrame(image, frame.rotationDegrees);
    } catch (e) {
      _waiter = null;
      throw SieVisionFailure(
        code: 'sie.vision.process_frame',
        message: e.toString(),
        cause: e,
      );
    }

    try {
      return await completer.future.timeout(
        const Duration(milliseconds: 250),
        onTimeout: () {
          _waiter = null;
          return const HandLandmarkerBackendResult(hands: [], inferenceMs: 250);
        },
      );
    } catch (e) {
      _waiter = null;
      rethrow;
    }
  }

  List<SieDetectedHand> _mapHands(List<Hand> hands) {
    final out = <SieDetectedHand>[];
    for (var i = 0; i < hands.length; i++) {
      final h = hands[i];
      final landmarks = h.landmarks
          .map((lm) => SieHandLandmark(x: lm.x, y: lm.y, z: lm.z))
          .toList(growable: false);
      out.add(
        SieDetectedHand(
          landmarks: landmarks,
          handedness: SieHandedness.unknown,
          handednessScore: 0,
          handConfidence: landmarks.isEmpty ? 0 : 0.85,
          index: i,
        ),
      );
    }
    return out;
  }

  @override
  Future<void> startLiveCapture(
    HandLandmarkerLiveResultCallback onResult, {
    SieVisionConfig? config,
  }) async {
    throw UnsupportedError('Android uses camera frame detect path');
  }

  @override
  Future<void> stopLiveCapture() async {}

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _waiter = null;
    _plugin?.dispose();
    _plugin = null;
  }
}
