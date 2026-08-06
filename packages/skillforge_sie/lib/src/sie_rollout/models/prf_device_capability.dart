import 'package:skillforge_sie/src/sie_core/platform_kind.dart';

/// Immutable device capability probe result.
final class PrfDeviceCapability {
  /// Creates capability.
  const PrfDeviceCapability({
    required this.platform,
    this.cameraAvailable = false,
    this.cameraWidth = 0,
    this.cameraHeight = 0,
    this.cameraFps = 0,
    this.cpuScore = 1,
    this.gpuAvailable = true,
    this.ramMb = 4096,
    this.mediaPipeCompatible = false,
    this.webGlAvailable = false,
    this.webGpuAvailable = false,
    this.osSupported = true,
    this.browserSupported = true,
  });

  /// Capable desktop/web stub for tests.
  factory PrfDeviceCapability.capable(SiePlatformKind platform) =>
      PrfDeviceCapability(
        platform: platform,
        cameraAvailable: true,
        cameraWidth: 1280,
        cameraHeight: 720,
        cameraFps: 30,
        cpuScore: 0.8,
        gpuAvailable: true,
        ramMb: 8192,
        mediaPipeCompatible: true,
        webGlAvailable: platform == SiePlatformKind.web,
        webGpuAvailable: false,
        osSupported: true,
        browserSupported: platform != SiePlatformKind.web || true,
      );

  /// Insufficient device.
  factory PrfDeviceCapability.insufficient(SiePlatformKind platform) =>
      PrfDeviceCapability(
        platform: platform,
        cameraAvailable: false,
        mediaPipeCompatible: false,
        osSupported: platform != SiePlatformKind.unsupported,
      );

  /// Platform.
  final SiePlatformKind platform;

  /// Camera present.
  final bool cameraAvailable;

  /// Resolution width.
  final int cameraWidth;

  /// Resolution height.
  final int cameraHeight;

  /// Camera FPS estimate.
  final double cameraFps;

  /// Relative CPU score 0–1.
  final double cpuScore;

  /// GPU.
  final bool gpuAvailable;

  /// RAM MB.
  final int ramMb;

  /// MediaPipe.
  final bool mediaPipeCompatible;

  /// WebGL.
  final bool webGlAvailable;

  /// WebGPU.
  final bool webGpuAvailable;

  /// OS supported.
  final bool osSupported;

  /// Browser supported (web).
  final bool browserSupported;

  /// Minimum acceptable for SIE.
  bool get isEligible {
    if (!osSupported) return false;
    if (platform == SiePlatformKind.unsupported) return false;
    if (platform == SiePlatformKind.web && !browserSupported) return false;
    if (platform == SiePlatformKind.web && !webGlAvailable && !webGpuAvailable) {
      return false;
    }
    if (!cameraAvailable) return false;
    if (!mediaPipeCompatible) return false;
    if (cameraWidth < 640 || cameraHeight < 480) return false;
    if (cameraFps > 0 && cameraFps < 15) return false;
    if (cpuScore < 0.25) return false;
    if (ramMb < 1024) return false;
    return true;
  }
}

/// Rolling telemetry sample for quality gates (not per-frame Riverpod).
final class PrfTelemetrySample {
  /// Creates sample.
  const PrfTelemetrySample({
    required this.timestamp,
    this.averageFps = 60,
    this.cameraFps = 30,
    this.trackingStability = 1,
    this.gestureConfidence = 1,
    this.cursorLatencyMs = 0,
    this.processingLatencyMs = 0,
    this.cpuUsage = 0,
    this.memoryMb = 0,
    this.thermalOk = true,
    this.lostTrackingRate = 0,
    this.falseClickRate = 0,
    this.crashRate = 0,
  });

  /// Healthy defaults.
  static PrfTelemetrySample healthy([DateTime? at]) => PrfTelemetrySample(
        timestamp: at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// Timestamp.
  final DateTime timestamp;

  /// Avg FPS.
  final double averageFps;

  /// Camera FPS.
  final double cameraFps;

  /// Tracking stability.
  final double trackingStability;

  /// Gesture confidence.
  final double gestureConfidence;

  /// Cursor latency.
  final double cursorLatencyMs;

  /// Processing latency.
  final double processingLatencyMs;

  /// CPU 0–1.
  final double cpuUsage;

  /// Memory MB.
  final double memoryMb;

  /// Thermal OK.
  final bool thermalOk;

  /// Lost tracking rate.
  final double lostTrackingRate;

  /// False click rate.
  final double falseClickRate;

  /// Crash rate.
  final double crashRate;

  /// Compact summary map.
  Map<String, Object?> toSummary() => {
        'averageFps': averageFps,
        'cameraFps': cameraFps,
        'trackingStability': trackingStability,
        'gestureConfidence': gestureConfidence,
        'cursorLatencyMs': cursorLatencyMs,
        'processingLatencyMs': processingLatencyMs,
        'cpuUsage': cpuUsage,
        'memoryMb': memoryMb,
        'thermalOk': thermalOk,
        'lostTrackingRate': lostTrackingRate,
        'falseClickRate': falseClickRate,
        'crashRate': crashRate,
      };
}
