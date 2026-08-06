import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_feature_flags.dart';
import 'package:skillforge_sie/src/sie_diagnostics/processing/sidf_recording.dart';

/// Low-frequency SIDF status (Riverpod-safe).
final class SidfFrameworkStatus {
  /// Creates status.
  const SidfFrameworkStatus({
    required this.health,
    required this.enabled,
    required this.overlayVisible,
    required this.recording,
    this.lastEvent,
  });

  /// Idle.
  factory SidfFrameworkStatus.idle() => const SidfFrameworkStatus(
        health: SidfFrameworkHealth.idle,
        enabled: false,
        overlayVisible: false,
        recording: false,
      );

  /// Health.
  final SidfFrameworkHealth health;

  /// Framework enabled.
  final bool enabled;

  /// Overlay visible.
  final bool overlayVisible;

  /// Recording.
  final bool recording;

  /// Last event.
  final String? lastEvent;

  /// Copy.
  SidfFrameworkStatus copyWith({
    SidfFrameworkHealth? health,
    bool? enabled,
    bool? overlayVisible,
    bool? recording,
    String? lastEvent,
  }) {
    return SidfFrameworkStatus(
      health: health ?? this.health,
      enabled: enabled ?? this.enabled,
      overlayVisible: overlayVisible ?? this.overlayVisible,
      recording: recording ?? this.recording,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

/// SIDF port — passive observer only (zero production side effects).
abstract interface class SidfDiagnosticsPort {
  /// Low-frequency status.
  Stream<SidfFrameworkStatus> get status;

  /// Diagnostics snapshots (internal high-freq when enabled — not Riverpod).
  Stream<SidfDiagnosticsSnapshot> get snapshots;

  /// Current status.
  SidfFrameworkStatus get currentStatus;

  /// Feature flags.
  SidfFeatureFlags get flags;

  /// Overlay config.
  SidfOverlayConfig get overlayConfig;

  /// Latest snapshot (may be empty).
  SidfDiagnosticsSnapshot get latestSnapshot;

  /// Timeline events.
  List<SidfTimelineEvent> get timeline;

  /// Initialize (no-op if release-disabled).
  Future<void> initialize({
    SidfFeatureFlags? flags,
    SidfOverlayConfig? overlayConfig,
  });

  /// Update flags.
  Future<void> setFlags(SidfFeatureFlags flags);

  /// Overlay visibility.
  Future<void> setOverlayVisible(bool visible);

  /// Update overlay config.
  Future<void> setOverlayConfig(SidfOverlayConfig config);

  /// Ingest stage sample (ignored when disabled).
  void ingestStage(SidfStageSample sample);

  /// Ingest skeleton.
  void ingestSkeleton(SidfSkeletonFrame frame);

  /// Ingest coordinates.
  void ingestCoordinates(SidfCoordinateSample sample);

  /// Ingest cursor.
  void ingestCursor(SidfCursorDebug cursor);

  /// Ingest gesture.
  void ingestGesture(SidfGestureDebug gesture);

  /// Ingest intent name.
  void ingestIntent(String? intent);

  /// Ingest pointer lifecycle.
  void ingestPointerLifecycle(String? lifecycle);

  /// Ingest arbitration owner.
  void ingestOwner(String? owner);

  /// Ingest route.
  void ingestRoute(String? route);

  /// Ingest confidence.
  void ingestConfidence(double confidence);

  /// Ingest a11y summary.
  void ingestAccessibility(String? summary);

  /// Push timeline event.
  void recordTimeline(SidfTimelineEvent event);

  /// Note e2e latency.
  void noteEndToEndLatency(double ms);

  /// Note camera/vision frame timing.
  void noteCameraFrame(DateTime at);

  /// Note vision frame.
  void noteVisionFrame(DateTime at);

  /// Note UI fps.
  void noteUiFps(double fps);

  /// Publish aggregated snapshot (call from host ticker / after ingest).
  SidfDiagnosticsSnapshot publish();

  /// Start recording (opt-in; no camera frames).
  Future<void> startRecording();

  /// Stop recording.
  Future<SidfRecordingSession?> stopRecording();

  /// Export JSON diagnostics.
  Map<String, Object?> exportJson();

  /// Export performance CSV (from last recording or live window).
  String exportPerformanceCsv();

  /// Export timeline CSV.
  String exportTimelineCsv();

  /// Export health report.
  String exportHealthReport();

  /// Dispose.
  Future<void> dispose();
}
