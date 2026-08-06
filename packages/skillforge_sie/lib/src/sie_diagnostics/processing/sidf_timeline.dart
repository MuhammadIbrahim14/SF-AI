import 'dart:collection';

import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/processing/sie_latency_stats.dart';

/// Bounded chronological event timeline (ring buffer via [Queue]).
final class SidfEventTimeline {
  /// Creates timeline.
  SidfEventTimeline({this.capacity = 256});

  /// Max events retained.
  final int capacity;

  final Queue<SidfTimelineEvent> _events = Queue<SidfTimelineEvent>();

  /// Current events (oldest → newest).
  List<SidfTimelineEvent> get events =>
      List<SidfTimelineEvent>.unmodifiable(_events.toList(growable: false));

  /// Count.
  int get length => _events.length;

  /// Clear.
  void clear() => _events.clear();

  /// Append event (drops oldest when full) — O(1) amortized.
  void add(SidfTimelineEvent event) {
    _events.addLast(event);
    while (_events.length > capacity) {
      _events.removeFirst();
    }
  }

  /// Tail of [n] events.
  List<SidfTimelineEvent> tail(int n) {
    if (n <= 0 || _events.isEmpty) return const [];
    if (n >= _events.length) return events;
    final all = _events.toList(growable: false);
    return List.unmodifiable(all.sublist(all.length - n));
  }

  /// JSON list.
  List<Map<String, Object?>> toJson() =>
      _events.map((e) => e.toJson()).toList(growable: false);
}

/// Rolling-window performance aggregator.
final class SidfTelemetryAggregator {
  /// Creates aggregator.
  SidfTelemetryAggregator({this.windowSize = 60, this.spikeThresholdMs = 40});

  /// Sample window.
  final int windowSize;

  /// Spike threshold.
  final double spikeThresholdMs;

  final Queue<double> _e2e = Queue<double>();
  final Map<SidfPipelineStage, double> _lastLatency = {};
  double _cameraFps = 0;
  double _visionFps = 0;
  double _uiFps = 0;
  int _spikes = 0;
  DateTime? _lastCameraAt;
  DateTime? _lastVisionAt;

  /// Note stage latency.
  void noteStage(SidfPipelineStage stage, double ms) {
    _lastLatency[stage] = ms;
  }

  /// Note camera frame.
  void noteCameraFrame(DateTime at) {
    final prev = _lastCameraAt;
    _lastCameraAt = at;
    if (prev != null) {
      final dt = at.difference(prev).inMicroseconds / 1000.0;
      if (dt > 0) _cameraFps = 1000.0 / dt;
    }
  }

  /// Note vision frame.
  void noteVisionFrame(DateTime at) {
    final prev = _lastVisionAt;
    _lastVisionAt = at;
    if (prev != null) {
      final dt = at.difference(prev).inMicroseconds / 1000.0;
      if (dt > 0) _visionFps = 1000.0 / dt;
    }
  }

  /// Note UI tick.
  void noteUiFps(double fps) => _uiFps = fps;

  /// Note end-to-end latency sample — O(1) window trim.
  void noteEndToEnd(double ms) {
    _e2e.addLast(ms);
    while (_e2e.length > windowSize) {
      _e2e.removeFirst();
    }
    if (ms >= spikeThresholdMs) _spikes++;
  }

  /// Reset.
  void reset() {
    _e2e.clear();
    _lastLatency.clear();
    _cameraFps = 0;
    _visionFps = 0;
    _uiFps = 0;
    _spikes = 0;
    _lastCameraAt = null;
    _lastVisionAt = null;
  }

  /// Snapshot (includes percentile distribution over the rolling window).
  SidfPerformanceSnapshot snapshot(DateTime now) {
    final samples = _e2e.toList(growable: false);
    final dist = SieLatencyStats.fromSamples(samples);
    final last = samples.isEmpty ? 0.0 : samples.last;
    return SidfPerformanceSnapshot(
      timestamp: now,
      endToEndMs: last,
      cameraFps: _cameraFps,
      visionFps: _visionFps,
      uiFps: _uiFps,
      stageLatenciesMs: Map.unmodifiable(_lastLatency),
      averageEndToEndMs: dist.averageMs,
      medianEndToEndMs: dist.medianMs,
      p95EndToEndMs: dist.p95Ms,
      p99EndToEndMs: dist.p99Ms,
      minEndToEndMs: dist.minMs,
      maxEndToEndMs: dist.maxMs,
      spikeCount: _spikes,
    );
  }
}
