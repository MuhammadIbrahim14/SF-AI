import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Per-stage health + latency sample (immutable).
final class SidfStageSample {
  /// Creates sample.
  const SidfStageSample({
    required this.stage,
    required this.health,
    required this.timestamp,
    this.processingMs = 0,
    this.fps = 0,
    this.label,
    this.metadata = const {},
  });

  /// Stage.
  final SidfPipelineStage stage;

  /// Health.
  final SidfStageHealth health;

  /// Timestamp.
  final DateTime timestamp;

  /// Last processing ms.
  final double processingMs;

  /// Estimated FPS for stage.
  final double fps;

  /// Short status label.
  final String? label;

  /// Extra metadata (no PII / no frames).
  final Map<String, Object?> metadata;
}

/// Landmark viz point (engineering overlay only).
final class SidfLandmarkVizPoint {
  /// Creates point.
  const SidfLandmarkVizPoint({
    required this.index,
    required this.position,
    this.confidence = 1,
  });

  /// Index 0–20.
  final int index;

  /// Flutter logical position (or normalized if flagged).
  final SieSpatialPoint2D position;

  /// Confidence.
  final double confidence;
}

/// Hand skeleton visualization payload.
final class SidfSkeletonFrame {
  /// Creates frame.
  const SidfSkeletonFrame({
    required this.timestamp,
    required this.landmarks,
    this.palmCenter,
    this.boundingBox,
    this.handId = 0,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Landmarks.
  final List<SidfLandmarkVizPoint> landmarks;

  /// Palm center.
  final SieSpatialPoint2D? palmCenter;

  /// Bounding box.
  final SieSpatialRect? boundingBox;

  /// Hand id.
  final int handId;
}

/// Coordinate stage sample for viz.
final class SidfCoordinateSample {
  /// Creates sample.
  const SidfCoordinateSample({
    required this.timestamp,
    this.camera,
    this.normalized,
    this.screen,
    this.flutter,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Camera space tip.
  final SieSpatialPoint2D? camera;

  /// Normalized.
  final SieSpatialPoint2D? normalized;

  /// Screen.
  final SieSpatialPoint2D? screen;

  /// Flutter logical.
  final SieSpatialPoint2D? flutter;
}

/// Cursor debug payload.
final class SidfCursorDebug {
  /// Creates debug.
  const SidfCursorDebug({
    required this.timestamp,
    required this.position,
    this.velocity = SieSpatialPoint2D.zero,
    this.prediction = SieSpatialPoint2D.zero,
    this.smoothingAlpha = 0,
    this.state = 'unknown',
    this.snapRadius = 0,
    this.hoverTargetId,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Position.
  final SieSpatialPoint2D position;

  /// Velocity.
  final SieSpatialPoint2D velocity;

  /// Prediction offset.
  final SieSpatialPoint2D prediction;

  /// Smoothing alpha.
  final double smoothingAlpha;

  /// State name.
  final String state;

  /// Snap radius.
  final double snapRadius;

  /// Hover target.
  final String? hoverTargetId;
}

/// Gesture debug payload.
final class SidfGestureDebug {
  /// Creates debug.
  const SidfGestureDebug({
    required this.timestamp,
    this.primary,
    this.phase,
    this.confidence = 0,
    this.armingProgress = 0,
    this.candidate,
    this.activity,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Primary gesture.
  final String? primary;

  /// Phase.
  final String? phase;

  /// Confidence.
  final double confidence;

  /// Arming progress.
  final double armingProgress;

  /// Candidate.
  final String? candidate;

  /// Activity.
  final String? activity;
}

/// Timeline entry.
final class SidfTimelineEvent {
  /// Creates event.
  const SidfTimelineEvent({
    required this.timestamp,
    required this.category,
    required this.name,
    this.detail,
    this.metadata = const {},
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Category.
  final SidfTimelineCategory category;

  /// Event name.
  final String name;

  /// Detail.
  final String? detail;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'category': category.name,
        'name': name,
        if (detail != null) 'detail': detail,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// Rolling performance telemetry snapshot.
final class SidfPerformanceSnapshot {
  /// Creates snapshot.
  const SidfPerformanceSnapshot({
    required this.timestamp,
    this.endToEndMs = 0,
    this.cameraFps = 0,
    this.visionFps = 0,
    this.uiFps = 0,
    this.stageLatenciesMs = const {},
    this.averageEndToEndMs = 0,
    this.medianEndToEndMs = 0,
    this.p95EndToEndMs = 0,
    this.p99EndToEndMs = 0,
    this.minEndToEndMs = 0,
    this.maxEndToEndMs = 0,
    this.spikeCount = 0,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Last e2e ms.
  final double endToEndMs;

  /// Camera FPS.
  final double cameraFps;

  /// Vision FPS.
  final double visionFps;

  /// UI / overlay FPS estimate.
  final double uiFps;

  /// Per-stage last latency.
  final Map<SidfPipelineStage, double> stageLatenciesMs;

  /// Rolling average e2e.
  final double averageEndToEndMs;

  /// Rolling median (p50) e2e.
  final double medianEndToEndMs;

  /// Rolling p95 e2e.
  final double p95EndToEndMs;

  /// Rolling p99 e2e.
  final double p99EndToEndMs;

  /// Rolling min e2e.
  final double minEndToEndMs;

  /// Rolling max e2e.
  final double maxEndToEndMs;

  /// Perf spikes observed.
  final int spikeCount;

  /// JSON.
  Map<String, Object?> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'endToEndMs': endToEndMs,
        'cameraFps': cameraFps,
        'visionFps': visionFps,
        'uiFps': uiFps,
        'averageEndToEndMs': averageEndToEndMs,
        'medianEndToEndMs': medianEndToEndMs,
        'p95EndToEndMs': p95EndToEndMs,
        'p99EndToEndMs': p99EndToEndMs,
        'minEndToEndMs': minEndToEndMs,
        'maxEndToEndMs': maxEndToEndMs,
        'spikeCount': spikeCount,
        'stageLatenciesMs': {
          for (final e in stageLatenciesMs.entries) e.key.name: e.value,
        },
      };
}

/// Aggregated diagnostics frame for overlay / export (immutable).
final class SidfDiagnosticsSnapshot {
  /// Creates snapshot.
  const SidfDiagnosticsSnapshot({
    required this.timestamp,
    required this.stages,
    required this.performance,
    this.skeleton,
    this.coordinates,
    this.cursor,
    this.gesture,
    this.intent,
    this.pointerLifecycle,
    this.inputOwner,
    this.route,
    this.accessibilitySummary,
    this.confidence = 0,
    this.recentTimeline = const [],
    this.recording = false,
    this.metadata = const {},
  });

  /// Empty idle.
  factory SidfDiagnosticsSnapshot.empty(DateTime timestamp) =>
      SidfDiagnosticsSnapshot(
        timestamp: timestamp,
        stages: {
          for (final s in SidfPipelineStage.values)
            s: SidfStageSample(
              stage: s,
              health: SidfStageHealth.unknown,
              timestamp: timestamp,
            ),
        },
        performance: SidfPerformanceSnapshot(timestamp: timestamp),
      );

  /// Timestamp.
  final DateTime timestamp;

  /// Stage map.
  final Map<SidfPipelineStage, SidfStageSample> stages;

  /// Performance.
  final SidfPerformanceSnapshot performance;

  /// Skeleton.
  final SidfSkeletonFrame? skeleton;

  /// Coordinates.
  final SidfCoordinateSample? coordinates;

  /// Cursor.
  final SidfCursorDebug? cursor;

  /// Gesture.
  final SidfGestureDebug? gesture;

  /// Active intent name.
  final String? intent;

  /// Pointer lifecycle name.
  final String? pointerLifecycle;

  /// Input owner.
  final String? inputOwner;

  /// Route.
  final String? route;

  /// A11y summary.
  final String? accessibilitySummary;

  /// Confidence.
  final double confidence;

  /// Recent timeline (tail).
  final List<SidfTimelineEvent> recentTimeline;

  /// Recording active.
  final bool recording;

  /// Metadata.
  final Map<String, Object?> metadata;
}
