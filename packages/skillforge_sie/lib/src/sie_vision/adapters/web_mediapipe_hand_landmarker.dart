import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_image_format.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_detected_hand.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_hand_landmark.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';
import 'package:skillforge_sie/src/sie_vision/util/yuv_to_rgba.dart';

/// Web MediaPipe Tasks Vision Hand Landmarker via JS bridge.
HandLandmarkerBackendPort createWebMediaPipeHandLandmarkerBackend() =>
    WebMediaPipeHandLandmarkerBackend();

@JS('sieHandLandmarker')
external SieHandLandmarkerJs get _bridge;

/// JS interop surface for `window.sieHandLandmarker`.
extension type SieHandLandmarkerJs(JSObject _) implements JSObject {
  /// Initializes MediaPipe Hand Landmarker (IMAGE warm-up).
  external JSPromise<JSAny?> init(JSObject options);

  /// Starts getUserMedia + VIDEO detection loop.
  external JSPromise<JSAny?> startLive(JSFunction callback, JSObject options);

  /// Stops live VIDEO loop and camera tracks.
  external void stopLive();

  /// Runs IMAGE-mode detection on an RGBA buffer.
  external JSString detectRgba(
    JSAny rgba,
    int width,
    int height,
  );

  /// Releases the JS landmarker.
  external void dispose();
}

bool _hasBridge() => globalContext.has('sieHandLandmarker');

/// Production Web adapter — live VIDEO capture is the primary path on Chrome.
final class WebMediaPipeHandLandmarkerBackend
    implements HandLandmarkerBackendPort {
  bool _initialized = false;
  bool _live = false;
  SieVisionConfig _config = SieVisionConfig.sieDefaults;

  /// Retained so the JS→Dart callback is not garbage-collected.
  JSFunction? _retainedLiveCallback;
  HandLandmarkerLiveResultCallback? _onResult;
  int _liveFrames = 0;
  int _liveHands = 0;

  @override
  SieVisionBackendKind get kind => SieVisionBackendKind.mediaPipeHandLandmarker;

  @override
  bool get isSupported => true;

  @override
  bool get supportsLiveCapture => true;

  /// Live frames received from JS (diagnostics).
  int get liveFrameCount => _liveFrames;

  /// Live frames that contained at least one hand.
  int get liveHandFrameCount => _liveHands;

  @override
  Future<void> initialize(SieVisionConfig config) async {
    _config = config;
    for (var i = 0; i < 80; i++) {
      if (_hasBridge()) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!_hasBridge()) {
      throw SieVisionInitFailure(
        message:
            'window.sieHandLandmarker missing. Ensure web/sie_hand_landmarker_bridge.js is loaded in index.html.',
      );
    }
    final options = _optionsJs(config);
    await _bridge.init(options).toDart;
    _initialized = true;
  }

  @override
  Future<void> startLiveCapture(
    HandLandmarkerLiveResultCallback onResult, {
    SieVisionConfig? config,
  }) async {
    if (!_initialized) {
      await initialize(config ?? _config);
    }
    if (config != null) _config = config;
    if (_live) await stopLiveCapture();

    _onResult = onResult;
    _liveFrames = 0;
    _liveHands = 0;

    // Keep a strong reference — critical for dart2js/wasm GC.
    // Accept JSAny: JSON.stringify yields a plain JS string; typing as
    // JSString alone can fail interop on some dart2js builds.
    void handleJs(JSAny? payload) {
      if (payload == null) return;
      final json = payload.isA<JSString>()
          ? (payload as JSString).toDart
          : payload.dartify()?.toString() ?? '';
      _handleLiveJson(json);
    }

    _retainedLiveCallback = handleJs.toJS;
    await _bridge.startLive(_retainedLiveCallback!, _optionsJs(_config)).toDart;
    _live = true;
    assert(() {
      debugPrint('[sie.vision.web] live capture started');
      return true;
    }());
  }

  void _handleLiveJson(String jsonPayload) {
    if (jsonPayload.isEmpty || _onResult == null) return;
    try {
      final map = jsonDecode(jsonPayload) as Map<String, dynamic>;
      if (map['error'] != null) {
        assert(() {
          debugPrint('[sie.vision.web] live error: ${map['error']}');
          return true;
        }());
        return;
      }
      final result = _parseResult(map);
      _liveFrames++;
      if (result.hands.isNotEmpty) _liveHands++;
      if (_liveFrames == 1 || _liveFrames % 60 == 0) {
        assert(() {
          debugPrint(
            '[sie.vision.web] frames=$_liveFrames hands=$_liveHands '
            'lastHands=${result.hands.length}',
          );
          return true;
        }());
      }
      _onResult!(result);
    } catch (e, st) {
      assert(() {
        debugPrint('[sie.vision.web] live parse failed: $e\n$st');
        return true;
      }());
    }
  }

  @override
  Future<void> stopLiveCapture() async {
    if (!_live) return;
    try {
      if (_hasBridge()) _bridge.stopLive();
    } catch (_) {}
    _live = false;
    _onResult = null;
    // Keep _retainedLiveCallback until dispose so late JS frames don't crash.
  }

  @override
  Future<HandLandmarkerBackendResult> detect(SieCameraFrame frame) async {
    if (!_initialized) {
      throw SieVisionFailure(
        code: 'sie.vision.not_initialized',
        message: 'Web MediaPipe backend is not initialized.',
      );
    }
    if (_live) {
      return const HandLandmarkerBackendResult(hands: [], inferenceMs: 0);
    }
    final rgba = _toRgba(frame);
    if (rgba == null) {
      return const HandLandmarkerBackendResult(hands: [], inferenceMs: 0);
    }
    final json = _bridge
        .detectRgba(rgba.toJS, frame.width, frame.height)
        .toDart;
    final map = jsonDecode(json) as Map<String, dynamic>;
    if (map['error'] != null) {
      throw SieVisionFailure(
        code: 'sie.vision.js',
        message: map['error'].toString(),
      );
    }
    return _parseResult(map);
  }

  static JSObject _optionsJs(SieVisionConfig config) {
    return <String, Object?>{
      'numHands': config.numHands,
      'minHandDetectionConfidence': config.minHandDetectionConfidence,
      'minHandPresenceConfidence': config.minHandPresenceConfidence,
      'minTrackingConfidence': config.minTrackingConfidence,
    }.jsify()! as JSObject;
  }

  static HandLandmarkerBackendResult _parseResult(Map<String, dynamic> map) {
    final handsRaw = map['hands'] as List<dynamic>? ?? const [];
    final hands = <SieDetectedHand>[];
    for (final h in handsRaw) {
      final hm = h as Map<String, dynamic>;
      final lms = (hm['landmarks'] as List<dynamic>)
          .map((e) {
            final m = e as Map<String, dynamic>;
            return SieHandLandmark(
              x: (m['x'] as num).toDouble(),
              y: (m['y'] as num).toDouble(),
              z: (m['z'] as num?)?.toDouble() ?? 0,
              visibility: (m['visibility'] as num?)?.toDouble(),
              presence: (m['presence'] as num?)?.toDouble(),
            );
          })
          .toList(growable: false);
      hands.add(
        SieDetectedHand(
          landmarks: lms,
          handedness: _parseHandedness(hm['handedness']?.toString()),
          handednessScore: (hm['handednessScore'] as num?)?.toDouble() ?? 0,
          handConfidence: (hm['handConfidence'] as num?)?.toDouble() ?? 0,
          index: (hm['index'] as num?)?.toInt() ?? hands.length,
        ),
      );
    }
    return HandLandmarkerBackendResult(
      hands: hands,
      inferenceMs: (map['inferMs'] as num?)?.toDouble() ?? 0,
      frameSequence: (map['frameSequence'] as num?)?.toInt() ?? 0,
    );
  }

  static SieHandedness _parseHandedness(String? raw) {
    switch (raw) {
      case 'left':
        return SieHandedness.left;
      case 'right':
        return SieHandedness.right;
      default:
        return SieHandedness.unknown;
    }
  }

  static Uint8List? _toRgba(SieCameraFrame frame) {
    if (frame.planes.isEmpty) return null;
    if (frame.format == SieCameraImageFormat.bgra8888 &&
        frame.planes.first.bytes.length >= frame.width * frame.height * 4) {
      final src = frame.planes.first.bytes;
      final out = Uint8List(frame.width * frame.height * 4);
      for (var i = 0, j = 0; j < out.length; i += 4, j += 4) {
        out[j] = src[i + 2];
        out[j + 1] = src[i + 1];
        out[j + 2] = src[i];
        out[j + 3] = src[i + 3];
      }
      return out;
    }
    if (frame.format == SieCameraImageFormat.yuv420 &&
        frame.planes.length >= 3) {
      return yuv420ToRgba(
        width: frame.width,
        height: frame.height,
        y: frame.planes[0].bytes,
        u: frame.planes[1].bytes,
        v: frame.planes[2].bytes,
        yRowStride: frame.planes[0].bytesPerRow,
        uRowStride: frame.planes[1].bytesPerRow,
        vRowStride: frame.planes[2].bytesPerRow,
      );
    }
    if (frame.planes.length == 1) {
      final y = frame.planes.first.bytes;
      final out = Uint8List(frame.width * frame.height * 4);
      var oi = 0;
      for (var i = 0; i < frame.width * frame.height && i < y.length; i++) {
        final p = y[i];
        out[oi++] = p;
        out[oi++] = p;
        out[oi++] = p;
        out[oi++] = 255;
      }
      return out;
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    await stopLiveCapture();
    _retainedLiveCallback = null;
    if (_hasBridge()) {
      try {
        _bridge.dispose();
      } catch (_) {}
    }
    _initialized = false;
  }
}
