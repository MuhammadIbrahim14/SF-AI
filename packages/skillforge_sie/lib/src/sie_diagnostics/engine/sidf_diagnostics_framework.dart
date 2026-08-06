import 'dart:async';

import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_diagnostics/logging/sidf_logger.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_feature_flags.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_diagnostics/processing/sidf_recording.dart';
import 'package:skillforge_sie/src/sie_diagnostics/processing/sidf_timeline.dart';

/// Production SIDF hub — observer only.
final class SidfDiagnosticsFramework implements SidfDiagnosticsPort {
  /// Creates framework.
  SidfDiagnosticsFramework({
    SidfFeatureFlags? flags,
    SidfOverlayConfig overlayConfig = SidfOverlayConfig.standard,
    SidfLogger logger = const DeveloperSidfLogger(),
  })  : _flags = flags ?? SidfFeatureFlags.forBuildMode(),
        _overlayConfig = overlayConfig,
        _logger = logger;

  final SidfLogger _logger;
  SidfFeatureFlags _flags;
  SidfOverlayConfig _overlayConfig;

  final StreamController<SidfFrameworkStatus> _statusController =
      StreamController<SidfFrameworkStatus>.broadcast();
  final StreamController<SidfDiagnosticsSnapshot> _snapshotController =
      StreamController<SidfDiagnosticsSnapshot>.broadcast();

  final SidfEventTimeline _timeline = SidfEventTimeline();
  final SidfTelemetryAggregator _telemetry = SidfTelemetryAggregator();
  final Map<SidfPipelineStage, SidfStageSample> _stages = {
    for (final s in SidfPipelineStage.values)
      s: SidfStageSample(
        stage: s,
        health: SidfStageHealth.unknown,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
  };

  SidfSkeletonFrame? _skeleton;
  SidfCoordinateSample? _coordinates;
  SidfCursorDebug? _cursor;
  SidfGestureDebug? _gesture;
  String? _intent;
  String? _pointerLifecycle;
  String? _owner;
  String? _route;
  String? _a11y;
  double _confidence = 0;
  bool _overlayVisible = false;
  SidfRecordingSession? _recording;
  SidfDiagnosticsSnapshot _latest =
      SidfDiagnosticsSnapshot.empty(DateTime.fromMillisecondsSinceEpoch(0));
  SidfFrameworkStatus _status = SidfFrameworkStatus.idle();
  bool _disposed = false;
  final List<SidfPerformanceSnapshot> _perfHistory = [];

  @override
  Stream<SidfFrameworkStatus> get status => _statusController.stream;

  @override
  Stream<SidfDiagnosticsSnapshot> get snapshots => _snapshotController.stream;

  @override
  SidfFrameworkStatus get currentStatus => _status;

  @override
  SidfFeatureFlags get flags => _flags;

  @override
  SidfOverlayConfig get overlayConfig => _overlayConfig;

  @override
  SidfDiagnosticsSnapshot get latestSnapshot => _latest;

  @override
  List<SidfTimelineEvent> get timeline => _timeline.events;

  void _emitStatus(SidfFrameworkStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  bool get _active => !_disposed && _flags.isObserving;

  @override
  Future<void> initialize({
    SidfFeatureFlags? flags,
    SidfOverlayConfig? overlayConfig,
  }) async {
    _ensureNotDisposed();
    if (flags != null) _flags = flags;
    if (overlayConfig != null) _overlayConfig = overlayConfig;
    _overlayVisible = _flags.overlay && _flags.frameworkEnabled;
    _logger.log(SidfLogLevel.info, 'sidf_initialized', {
      'enabled': _flags.frameworkEnabled,
      'releaseSafe': !_flags.frameworkEnabled,
    });
    _emitStatus(
      SidfFrameworkStatus(
        health: _flags.frameworkEnabled
            ? SidfFrameworkHealth.active
            : SidfFrameworkHealth.idle,
        enabled: _flags.frameworkEnabled,
        overlayVisible: _overlayVisible,
        recording: false,
        lastEvent: 'initialized',
      ),
    );
  }

  @override
  Future<void> setFlags(SidfFeatureFlags flags) async {
    _ensureNotDisposed();
    _flags = flags;
    if (!_flags.overlay) _overlayVisible = false;
    if (!_flags.recording && _recording != null) {
      await stopRecording();
    }
    _emitStatus(
      _status.copyWith(
        enabled: flags.frameworkEnabled,
        overlayVisible: _overlayVisible && flags.overlay,
        health: flags.frameworkEnabled
            ? (_recording != null
                ? SidfFrameworkHealth.recording
                : SidfFrameworkHealth.active)
            : SidfFrameworkHealth.idle,
        lastEvent: 'flags_changed',
      ),
    );
  }

  @override
  Future<void> setOverlayVisible(bool visible) async {
    _ensureNotDisposed();
    _overlayVisible = visible && _flags.overlay && _flags.frameworkEnabled;
    _emitStatus(
      _status.copyWith(
        overlayVisible: _overlayVisible,
        lastEvent: 'overlay_toggled',
      ),
    );
  }

  @override
  Future<void> setOverlayConfig(SidfOverlayConfig config) async {
    _ensureNotDisposed();
    _overlayConfig = config;
  }

  @override
  void ingestStage(SidfStageSample sample) {
    if (!_active) return;
    _stages[sample.stage] = sample;
    _telemetry.noteStage(sample.stage, sample.processingMs);
  }

  @override
  void ingestSkeleton(SidfSkeletonFrame frame) {
    if (!_active || !_flags.skeleton) return;
    _skeleton = frame;
  }

  @override
  void ingestCoordinates(SidfCoordinateSample sample) {
    if (!_active || !_flags.coordinates) return;
    _coordinates = sample;
  }

  @override
  void ingestCursor(SidfCursorDebug cursor) {
    if (!_active) return;
    if (_flags.cursorViz) _cursor = cursor;
    _recording?.addCursorPath(
      timestamp: cursor.timestamp,
      x: cursor.position.x,
      y: cursor.position.y,
      state: cursor.state,
    );
  }

  @override
  void ingestGesture(SidfGestureDebug gesture) {
    if (!_active) return;
    _gesture = gesture;
    _recording?.noteGesture(gesture.primary, gesture.timestamp);
  }

  @override
  void ingestIntent(String? intent) {
    if (!_active) return;
    _intent = intent;
  }

  @override
  void ingestPointerLifecycle(String? lifecycle) {
    if (!_active) return;
    _pointerLifecycle = lifecycle;
  }

  @override
  void ingestOwner(String? owner) {
    if (!_active) return;
    _owner = owner;
  }

  @override
  void ingestRoute(String? route) {
    if (!_active) return;
    _route = route;
  }

  @override
  void ingestConfidence(double confidence) {
    if (!_active) return;
    _confidence = confidence;
  }

  @override
  void ingestAccessibility(String? summary) {
    if (!_active) return;
    _a11y = summary;
  }

  @override
  void recordTimeline(SidfTimelineEvent event) {
    if (!_active || !_flags.timeline) return;
    _timeline.add(event);
    _recording?.addTimeline(event);
    if (_flags.logging) {
      _logger.log(SidfLogLevel.debug, 'timeline', {
        'name': event.name,
        'category': event.category.name,
      });
    }
  }

  @override
  void noteEndToEndLatency(double ms) {
    if (!_active) return;
    _telemetry.noteEndToEnd(ms);
    if (ms >= 40 && _flags.timeline) {
      recordTimeline(
        SidfTimelineEvent(
          timestamp: DateTime.now().toUtc(),
          category: SidfTimelineCategory.performance,
          name: 'latency_spike',
          detail: '${ms.toStringAsFixed(1)}ms',
        ),
      );
    }
  }

  @override
  void noteCameraFrame(DateTime at) {
    if (!_active) return;
    _telemetry.noteCameraFrame(at);
  }

  @override
  void noteVisionFrame(DateTime at) {
    if (!_active) return;
    _telemetry.noteVisionFrame(at);
  }

  @override
  void noteUiFps(double fps) {
    if (!_active) return;
    _telemetry.noteUiFps(fps);
  }

  @override
  SidfDiagnosticsSnapshot publish() {
    final now = DateTime.now().toUtc();
    if (!_active) {
      return SidfDiagnosticsSnapshot.empty(now);
    }
    final perf = _telemetry.snapshot(now);
    _perfHistory.add(perf);
    if (_perfHistory.length > 120) _perfHistory.removeAt(0);
    _recording?.addPerformance(perf);

    final snap = SidfDiagnosticsSnapshot(
      timestamp: now,
      stages: Map.unmodifiable(_stages),
      performance: perf,
      skeleton: _flags.skeleton ? _skeleton : null,
      coordinates: _flags.coordinates ? _coordinates : null,
      cursor: _flags.cursorViz ? _cursor : null,
      gesture: _gesture,
      intent: _intent,
      pointerLifecycle: _pointerLifecycle,
      inputOwner: _owner,
      route: _route,
      accessibilitySummary: _a11y,
      confidence: _confidence,
      recentTimeline: _flags.timeline ? _timeline.tail(32) : const [],
      recording: _recording != null,
    );
    _latest = snap;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snap);
    }
    return snap;
  }

  @override
  Future<void> startRecording() async {
    _ensureNotDisposed();
    if (!_flags.frameworkEnabled || !_flags.recording) {
      throw SieDiagnosticsFailure(
        message: 'Recording disabled by SIDF feature flags',
      );
    }
    if (_recording != null) return;
    _recording = SidfRecordingSession(startedAt: DateTime.now().toUtc());
    recordTimeline(
      SidfTimelineEvent(
        timestamp: DateTime.now().toUtc(),
        category: SidfTimelineCategory.lifecycle,
        name: 'recording_started',
      ),
    );
    _logger.log(SidfLogLevel.info, 'recording_started');
    _emitStatus(
      _status.copyWith(
        recording: true,
        health: SidfFrameworkHealth.recording,
        lastEvent: 'recording_started',
      ),
    );
  }

  @override
  Future<SidfRecordingSession?> stopRecording() async {
    _ensureNotDisposed();
    final session = _recording;
    if (session == null) return null;
    session.end();
    _recording = null;
    recordTimeline(
      SidfTimelineEvent(
        timestamp: DateTime.now().toUtc(),
        category: SidfTimelineCategory.lifecycle,
        name: 'recording_stopped',
      ),
    );
    _logger.log(SidfLogLevel.info, 'recording_stopped', {'id': session.id});
    _emitStatus(
      _status.copyWith(
        recording: false,
        health: _flags.frameworkEnabled
            ? SidfFrameworkHealth.active
            : SidfFrameworkHealth.idle,
        lastEvent: 'recording_stopped',
      ),
    );
    return session;
  }

  @override
  Map<String, Object?> exportJson() {
    return SidfExport.diagnosticsJson(
      snapshot: _latest,
      recording: _recording,
      timeline: _timeline.events,
    );
  }

  @override
  String exportPerformanceCsv() => SidfExport.performanceCsv(_perfHistory);

  @override
  String exportTimelineCsv() => SidfExport.timelineCsv(_timeline.events);

  @override
  String exportHealthReport() => SidfExport.healthReport(_latest);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _recording?.end();
    _recording = null;
    _logger.log(SidfLogLevel.info, 'sidf_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SidfFrameworkHealth.disposed,
        enabled: false,
        overlayVisible: false,
        recording: false,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieDiagnosticsFailure(message: 'SIDF is disposed.');
    }
  }
}
