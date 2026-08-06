import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_landmarks/models/sie_landmark_engine_config.dart';
import 'package:skillforge_sie/src/sie_landmarks/models/sie_normalized_landmark.dart';

/// Output of temporal stabilization.
final class SieStabilizationOutput {
  /// Creates stabilization output.
  const SieStabilizationOutput({
    required this.landmarks,
    required this.applied,
    required this.meanDelta,
  });

  /// Stabilized landmarks.
  final List<SieNormalizedLandmark> landmarks;

  /// Whether EMA was applied.
  final bool applied;

  /// Mean absolute xy delta vs previous frame (stability metric).
  final double meanDelta;
}

/// EMA temporal stabilizer per hand id (reduces jitter, keeps low latency).
///
/// Not thread-safe across isolates — one engine instance per pipeline.
final class SieLandmarkStabilizer {
  /// Creates a stabilizer.
  SieLandmarkStabilizer(this.config);

  /// Active config.
  SieLandmarkEngineConfig config;

  final Map<int, List<SieNormalizedLandmark>> _prev = {};

  /// Clears history (e.g. on stop / long loss).
  void reset() => _prev.clear();

  /// Drops history for a hand that disappeared.
  void clearHand(int handId) => _prev.remove(handId);

  /// Retains only [activeIds]; drops the rest.
  void retainHands(Iterable<int> activeIds) {
    final keep = activeIds.toSet();
    _prev.removeWhere((id, _) => !keep.contains(id));
  }

  /// Stabilizes [current] for [handId].
  SieStabilizationOutput stabilize({
    required int handId,
    required List<SieNormalizedLandmark> current,
  }) {
    if (!config.enableStabilization || current.isEmpty) {
      _prev[handId] = current;
      return SieStabilizationOutput(
        landmarks: current,
        applied: false,
        meanDelta: 0,
      );
    }

    final previous = _prev[handId];
    if (previous == null || previous.length != current.length) {
      _prev[handId] = current;
      return SieStabilizationOutput(
        landmarks: current,
        applied: false,
        meanDelta: 0,
      );
    }

    final alpha = config.stabilizationAlpha.clamp(0.05, 1.0);
    final out = <SieNormalizedLandmark>[];
    var deltaSum = 0.0;
    for (var i = 0; i < current.length; i++) {
      final c = current[i];
      final p = previous[i];
      final x = alpha * c.x + (1 - alpha) * p.x;
      final y = alpha * c.y + (1 - alpha) * p.y;
      final z = alpha * c.z + (1 - alpha) * p.z;
      deltaSum += (c.x - p.x).abs() + (c.y - p.y).abs();
      out.add(
        SieNormalizedLandmark(
          index: c.index,
          x: x,
          y: y,
          z: z,
          visibility: c.visibility,
          presence: c.presence,
        ),
      );
    }
    final immutable = List<SieNormalizedLandmark>.unmodifiable(out);
    _prev[handId] = immutable;
    final meanDelta = deltaSum / (current.length * 2);
    return SieStabilizationOutput(
      landmarks: immutable,
      applied: true,
      meanDelta: meanDelta,
    );
  }

  /// Maps mean delta to a 0–1 stability score (higher = stabler).
  static double stabilityScoreFromDelta(double meanDelta) {
    // Empirically: delta ~0 → 1.0; delta 0.05+ → approaches 0.
    return (1.0 - math.min(meanDelta / 0.05, 1.0)).clamp(0.0, 1.0);
  }
}
