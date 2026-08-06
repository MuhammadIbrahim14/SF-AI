import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';
import 'package:sie_camera_hand_cursor/platforms/spike_pipeline.dart';

SpikePipeline createPlatformSpikePipeline() => WebSpikePipeline();

@JS('sieSpike')
external SieSpikeJs get _sieSpike;

extension type SieSpikeJs(JSObject _) implements JSObject {
  external JSPromise<JSAny?> start(JSFunction callback);
  external void stop();
}

bool _hasSieSpike() {
  return globalContext.has('sieSpike');
}

class WebSpikePipeline implements SpikePipeline {
  HandSampleCallback? _onSample;
  bool _running = false;

  @override
  String get platformId => 'web';

  @override
  void Function()? onFrameCaptured;

  @override
  Widget? buildPreview(BuildContext context) => null;

  @override
  Future<void> start({required HandSampleCallback onSample}) async {
    _onSample = onSample;
    _running = true;

    for (var i = 0; i < 80; i++) {
      if (_hasSieSpike()) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!_hasSieSpike()) {
      throw StateError(
        'window.sieSpike missing — hand_landmarker_bridge.js failed to load.',
      );
    }

    final cb = ((JSAny payload) {
      if (!_running || _onSample == null) return;
      try {
        final jsonPayload = payload.dartify()?.toString() ?? '';
        if (jsonPayload.isEmpty) return;
        final map = jsonDecode(jsonPayload) as Map<String, dynamic>;
        final rawPts = (map['landmarks'] as List<dynamic>? ?? const []);
        final pts = rawPts.map((e) {
          final m = e as Map<String, dynamic>;
          return SpikeLandmark(
            x: (m['x'] as num).toDouble(),
            y: (m['y'] as num).toDouble(),
            z: (m['z'] as num?)?.toDouble() ?? 0,
          );
        }).toList();

        _onSample!(
          SpikeHandSample(
            detected: map['detected'] == true,
            confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
            landmarks: pts,
            inferMs: (map['inferMs'] as num?)?.toDouble() ?? 0,
            timestampMs: (map['timestampMs'] as num?)?.toDouble() ?? 0,
            cameraFpsHint: (map['cameraFps'] as num?)?.toDouble(),
          ),
        );
      } catch (e, st) {
        assert(() {
          // ignore: avoid_print
          print('WebSpikePipeline parse error: $e\n$st');
          return true;
        }());
      }
    }).toJS;

    await _sieSpike.start(cb).toDart;
  }

  @override
  Future<void> stop() async {
    _running = false;
    _onSample = null;
    try {
      if (_hasSieSpike()) _sieSpike.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
  }
}
