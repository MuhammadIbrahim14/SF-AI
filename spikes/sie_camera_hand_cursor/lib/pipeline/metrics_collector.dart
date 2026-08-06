import 'package:sie_camera_hand_cursor/models/spike_models.dart';

/// Rolling FPS / latency counters for the spike debug HUD.
class MetricsCollector {
  MetricsCollector(this.platform);

  final String platform;

  final List<DateTime> _visionMarks = [];
  final List<DateTime> _cursorMarks = [];
  final List<double> _latencySamples = [];
  final List<double> _inferSamples = [];

  DateTime? _sessionStart;
  DateTime? _frameCaptureHint;
  double cameraFps = 0;
  double startupMs = 0;

  void markSessionStart() {
    _sessionStart = DateTime.now();
  }

  void noteStartup(Duration d) {
    startupMs = d.inMilliseconds.toDouble();
  }

  void noteCameraFps(double fps) {
    cameraFps = fps;
  }

  /// Call when a camera frame is captured (Android).
  void markCameraFrame() {
    _frameCaptureHint = DateTime.now();
  }

  void onVisionSample(SpikeHandSample sample) {
    final now = DateTime.now();
    _visionMarks.add(now);
    _prune(_visionMarks, now);
    _inferSamples.add(sample.inferMs);
    if (_inferSamples.length > 60) _inferSamples.removeAt(0);

    if (sample.cameraFpsHint != null) {
      cameraFps = sample.cameraFpsHint!;
    }

    if (_frameCaptureHint != null) {
      final latency =
          now.difference(_frameCaptureHint!).inMicroseconds / 1000.0;
      _latencySamples.add(latency);
      if (_latencySamples.length > 60) _latencySamples.removeAt(0);
      _frameCaptureHint = null;
    } else {
      // Web: approximate latency as infer time + one frame budget.
      _latencySamples.add(sample.inferMs + 16);
      if (_latencySamples.length > 60) _latencySamples.removeAt(0);
    }
  }

  void onCursorTick() {
    final now = DateTime.now();
    _cursorMarks.add(now);
    _prune(_cursorMarks, now);
  }

  SpikeMetrics build({
    required TrackingState state,
    required bool handDetected,
    required double confidence,
    required int lossCount,
    required double lastRecoveryMs,
  }) {
    final now = DateTime.now();
    final session = _sessionStart == null
        ? 0.0
        : now.difference(_sessionStart!).inMilliseconds / 1000.0;

    return SpikeMetrics(
      platform: platform,
      cameraFps: cameraFps,
      visionFps: _fps(_visionMarks),
      cursorFps: _fps(_cursorMarks),
      latencyMs: _avg(_latencySamples),
      inferMs: _avg(_inferSamples),
      confidence: confidence,
      trackingState: state,
      handDetected: handDetected,
      startupMs: startupMs,
      sessionSeconds: session,
      lossCount: lossCount,
      lastRecoveryMs: lastRecoveryMs,
    );
  }

  void reset() {
    _visionMarks.clear();
    _cursorMarks.clear();
    _latencySamples.clear();
    _inferSamples.clear();
    cameraFps = 0;
    startupMs = 0;
    _sessionStart = null;
    _frameCaptureHint = null;
  }

  static void _prune(List<DateTime> marks, DateTime now) {
    marks.removeWhere((t) => now.difference(t).inMilliseconds > 1000);
  }

  static double _fps(List<DateTime> marks) => marks.length.toDouble();

  static double _avg(List<double> xs) {
    if (xs.isEmpty) return 0;
    return xs.reduce((a, b) => a + b) / xs.length;
  }
}
