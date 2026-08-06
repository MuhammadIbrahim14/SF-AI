/// Shared spike models (disposable PoC — not production SIE).
library;

enum TrackingState {
  idle,
  starting,
  searching,
  tracking,
  recovering,
  lost,
  permissionDenied,
  error,
}

class SpikeLandmark {
  const SpikeLandmark({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

class SpikeHandSample {
  const SpikeHandSample({
    required this.detected,
    required this.confidence,
    required this.landmarks,
    required this.inferMs,
    required this.timestampMs,
    this.cameraFpsHint,
  });

  final bool detected;
  final double confidence;
  final List<SpikeLandmark> landmarks;
  final double inferMs;
  final double timestampMs;
  final double? cameraFpsHint;

  /// Index fingertip (landmark 8) preferred for pointing; falls back to wrist.
  SpikeLandmark? get pointingLandmark {
    if (landmarks.length > 8) return landmarks[8];
    if (landmarks.isNotEmpty) return landmarks[0];
    return null;
  }
}

class SpikeMetrics {
  const SpikeMetrics({
    required this.platform,
    required this.cameraFps,
    required this.visionFps,
    required this.cursorFps,
    required this.latencyMs,
    required this.inferMs,
    required this.confidence,
    required this.trackingState,
    required this.handDetected,
    required this.startupMs,
    required this.sessionSeconds,
    required this.lossCount,
    required this.lastRecoveryMs,
  });

  final String platform;
  final double cameraFps;
  final double visionFps;
  final double cursorFps;
  final double latencyMs;
  final double inferMs;
  final double confidence;
  final TrackingState trackingState;
  final bool handDetected;
  final double startupMs;
  final double sessionSeconds;
  final int lossCount;
  final double lastRecoveryMs;

  SpikeMetrics copyWith({
    String? platform,
    double? cameraFps,
    double? visionFps,
    double? cursorFps,
    double? latencyMs,
    double? inferMs,
    double? confidence,
    TrackingState? trackingState,
    bool? handDetected,
    double? startupMs,
    double? sessionSeconds,
    int? lossCount,
    double? lastRecoveryMs,
  }) {
    return SpikeMetrics(
      platform: platform ?? this.platform,
      cameraFps: cameraFps ?? this.cameraFps,
      visionFps: visionFps ?? this.visionFps,
      cursorFps: cursorFps ?? this.cursorFps,
      latencyMs: latencyMs ?? this.latencyMs,
      inferMs: inferMs ?? this.inferMs,
      confidence: confidence ?? this.confidence,
      trackingState: trackingState ?? this.trackingState,
      handDetected: handDetected ?? this.handDetected,
      startupMs: startupMs ?? this.startupMs,
      sessionSeconds: sessionSeconds ?? this.sessionSeconds,
      lossCount: lossCount ?? this.lossCount,
      lastRecoveryMs: lastRecoveryMs ?? this.lastRecoveryMs,
    );
  }

  static SpikeMetrics empty(String platform) => SpikeMetrics(
        platform: platform,
        cameraFps: 0,
        visionFps: 0,
        cursorFps: 0,
        latencyMs: 0,
        inferMs: 0,
        confidence: 0,
        trackingState: TrackingState.idle,
        handDetected: false,
        startupMs: 0,
        sessionSeconds: 0,
        lossCount: 0,
        lastRecoveryMs: 0,
      );
}

class CursorState {
  const CursorState({
    required this.x,
    required this.y,
    required this.visible,
    required this.rawX,
    required this.rawY,
  });

  final double x;
  final double y;
  final bool visible;
  final double rawX;
  final double rawY;
}
