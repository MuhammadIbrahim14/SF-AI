import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/processing/sidf_timeline.dart';

/// Optional engineering session recording (no raw camera frames).
final class SidfRecordingSession {
  /// Creates session.
  SidfRecordingSession({
    required this.startedAt,
    this.includeCursorPath = true,
  }) : id = 'sidf_${startedAt.microsecondsSinceEpoch}';

  /// Session id.
  final String id;

  /// Start time.
  final DateTime startedAt;

  /// Whether to store cursor path samples.
  final bool includeCursorPath;

  final SidfEventTimeline _timeline = SidfEventTimeline(capacity: 2000);
  final List<SidfPerformanceSnapshot> _perf = [];
  final List<Map<String, Object?>> _cursorPath = [];
  final List<Map<String, Object?>> _gestureTransitions = [];
  DateTime? _endedAt;
  String? _lastGesture;

  /// Active.
  bool get isActive => _endedAt == null;

  /// Ended at.
  DateTime? get endedAt => _endedAt;

  /// Append timeline.
  void addTimeline(SidfTimelineEvent e) => _timeline.add(e);

  /// Append perf.
  void addPerformance(SidfPerformanceSnapshot p) {
    _perf.add(p);
    if (_perf.length > 2000) _perf.removeAt(0);
  }

  /// Cursor sample (positions only — no imagery).
  void addCursorPath({
    required DateTime timestamp,
    required double x,
    required double y,
    required String state,
  }) {
    if (!includeCursorPath) return;
    _cursorPath.add({
      't': timestamp.toIso8601String(),
      'x': x,
      'y': y,
      'state': state,
    });
    if (_cursorPath.length > 5000) _cursorPath.removeAt(0);
  }

  /// Gesture transition.
  void noteGesture(String? primary, DateTime timestamp) {
    if (primary == null || primary == _lastGesture) return;
    _gestureTransitions.add({
      't': timestamp.toIso8601String(),
      'from': _lastGesture,
      'to': primary,
    });
    _lastGesture = primary;
  }

  /// End session.
  void end([DateTime? at]) {
    _endedAt ??= at ?? DateTime.now().toUtc();
  }

  /// Export JSON-ready map (privacy-safe).
  Map<String, Object?> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': (_endedAt ?? DateTime.now().toUtc()).toIso8601String(),
        'privacy': {
          'rawCameraFrames': false,
          'note': 'SIDF never records raw camera imagery by default',
        },
        'timeline': _timeline.toJson(),
        'performance': _perf.map((p) => p.toJson()).toList(growable: false),
        'cursorPath': List<Map<String, Object?>>.of(_cursorPath),
        'gestureTransitions':
            List<Map<String, Object?>>.of(_gestureTransitions),
      };
}

/// Export helpers (engineering analysis only).
abstract final class SidfExport {
  /// JSON diagnostics document.
  static Map<String, Object?> diagnosticsJson({
    required SidfDiagnosticsSnapshot snapshot,
    SidfRecordingSession? recording,
    required List<SidfTimelineEvent> timeline,
  }) {
    return {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'type': 'sidf.diagnostics',
      'privacy': {'rawCameraFrames': false},
      'snapshot': {
        'timestamp': snapshot.timestamp.toIso8601String(),
        'intent': snapshot.intent,
        'owner': snapshot.inputOwner,
        'route': snapshot.route,
        'confidence': snapshot.confidence,
        'pointerLifecycle': snapshot.pointerLifecycle,
        'stages': {
          for (final e in snapshot.stages.entries)
            e.key.name: {
              'health': e.value.health.name,
              'processingMs': e.value.processingMs,
              'fps': e.value.fps,
              'label': e.value.label,
            },
        },
        'performance': snapshot.performance.toJson(),
      },
      'timeline': timeline.map((e) => e.toJson()).toList(growable: false),
      if (recording != null) 'recording': recording.toJson(),
    };
  }

  /// CSV performance metrics (header + rows).
  static String performanceCsv(List<SidfPerformanceSnapshot> samples) {
    final buf = StringBuffer(
      'timestamp,endToEndMs,averageEndToEndMs,cameraFps,visionFps,uiFps,spikeCount\n',
    );
    for (final s in samples) {
      buf.writeln(
        '${s.timestamp.toIso8601String()},'
        '${s.endToEndMs},${s.averageEndToEndMs},'
        '${s.cameraFps},${s.visionFps},${s.uiFps},${s.spikeCount}',
      );
    }
    return buf.toString();
  }

  /// Timeline as CSV.
  static String timelineCsv(List<SidfTimelineEvent> events) {
    final buf = StringBuffer('timestamp,category,name,detail\n');
    for (final e in events) {
      final detail = (e.detail ?? '').replaceAll(',', ';');
      buf.writeln(
        '${e.timestamp.toIso8601String()},${e.category.name},${e.name},$detail',
      );
    }
    return buf.toString();
  }

  /// System health report text.
  static String healthReport(SidfDiagnosticsSnapshot snapshot) {
    final buf = StringBuffer()
      ..writeln('SIDF System Health Report')
      ..writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('---');
    for (final stage in SidfPipelineStage.values) {
      final s = snapshot.stages[stage];
      buf.writeln(
        '${stage.name.padRight(14)} '
        '${(s?.health.name ?? 'unknown').padRight(10)} '
        '${(s?.processingMs ?? 0).toStringAsFixed(2)} ms  '
        '${s?.label ?? ''}',
      );
    }
    buf
      ..writeln('---')
      ..writeln(
        'E2E avg: ${snapshot.performance.averageEndToEndMs.toStringAsFixed(2)} ms',
      )
      ..writeln(
        'Camera FPS: ${snapshot.performance.cameraFps.toStringAsFixed(1)}',
      )
      ..writeln(
        'Vision FPS: ${snapshot.performance.visionFps.toStringAsFixed(1)}',
      );
    return buf.toString();
  }
}
