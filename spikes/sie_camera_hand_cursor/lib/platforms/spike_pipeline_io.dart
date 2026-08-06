import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';
import 'package:sie_camera_hand_cursor/platforms/spike_pipeline.dart';

SpikePipeline createPlatformSpikePipeline() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSpikePipeline();
  }
  return _IoUnsupportedPipeline();
}

class _IoUnsupportedPipeline implements SpikePipeline {
  @override
  String get platformId => 'unsupported-io';

  @override
  void Function()? onFrameCaptured;

  @override
  Widget? buildPreview(BuildContext context) => null;

  @override
  Future<void> start({required HandSampleCallback onSample}) async {
    throw UnsupportedError('This spike targets Android + Web only.');
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class AndroidSpikePipeline implements SpikePipeline {
  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  StreamSubscription<List<Hand>>? _sub;
  HandSampleCallback? _onSample;
  bool _busy = false;
  int _cameraFrames = 0;
  DateTime _cameraWindowStart = DateTime.now();
  double _cameraFps = 0;

  @override
  String get platformId => 'android';

  @override
  void Function()? onFrameCaptured;

  @override
  Widget? buildPreview(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.previewSize?.height ?? 640,
          height: c.value.previewSize?.width ?? 480,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  @override
  Future<void> start({required HandSampleCallback onSample}) async {
    _onSample = onSample;

    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      throw StateError('CAMERA_PERMISSION_DENIED');
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No cameras available');
    }
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    _plugin = HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.6,
      delegate: HandLandmarkerDelegate.gpu,
    );

    _sub = _plugin!.landmarkStream.listen((hands) {
      final now = DateTime.now();
      final landmarks = <SpikeLandmark>[];
      var detected = false;
      if (hands.isNotEmpty) {
        detected = true;
        for (final lm in hands.first.landmarks) {
          landmarks.add(SpikeLandmark(x: lm.x, y: lm.y, z: lm.z));
        }
      }
      _onSample?.call(
        SpikeHandSample(
          detected: detected,
          confidence: detected ? 0.85 : 0,
          landmarks: landmarks,
          inferMs: 0, // native path is async; infer bundled off-UI
          timestampMs: now.millisecondsSinceEpoch.toDouble(),
          cameraFpsHint: _cameraFps,
        ),
      );
    });

    _cameraWindowStart = DateTime.now();
    _cameraFrames = 0;
    await _controller!.startImageStream(_onCameraImage);
  }

  Future<void> _onCameraImage(CameraImage image) async {
    _cameraFrames++;
    final elapsed =
        DateTime.now().difference(_cameraWindowStart).inMilliseconds;
    if (elapsed >= 1000) {
      _cameraFps = _cameraFrames * 1000.0 / elapsed;
      _cameraFrames = 0;
      _cameraWindowStart = DateTime.now();
    }

    onFrameCaptured?.call();
    final plugin = _plugin;
    final controller = _controller;
    if (plugin == null || controller == null || _busy) return;
    _busy = true;
    try {
      plugin.processFrame(image, controller.description.sensorOrientation);
    } catch (e) {
      debugPrint('processFrame error: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    _plugin?.dispose();
    _plugin = null;
    _onSample = null;
  }

  @override
  void dispose() {
    stop();
  }
}
