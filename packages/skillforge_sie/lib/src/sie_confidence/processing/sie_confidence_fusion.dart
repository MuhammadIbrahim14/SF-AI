import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_sources.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Temporal tip-position stability tracker.
final class SieTemporalStabilityTracker {
  /// Creates tracker.
  SieTemporalStabilityTracker({required this.windowSize});

  /// Max samples retained.
  final int windowSize;

  final List<SieSpatialPoint2D> _tips = [];
  final List<bool> _present = [];

  /// Reset history.
  void reset() {
    _tips.clear();
    _present.clear();
  }

  /// Push a tip (null when no hand).
  void push(SieSpatialPoint2D? tip) {
    _tips.add(tip ?? const SieSpatialPoint2D(-1, -1));
    _present.add(tip != null);
    while (_tips.length > windowSize) {
      _tips.removeAt(0);
      _present.removeAt(0);
    }
  }

  /// Continuity score: fraction of recent frames with a hand.
  double continuityScore() {
    if (_present.isEmpty) return 0;
    var n = 0;
    for (final p in _present) {
      if (p) n++;
    }
    return n / _present.length;
  }

  /// Stability score from tip deltas (1 = still, 0 = wild).
  double stabilityScore(double deltaLimit) {
    if (_tips.length < 2) return _present.isNotEmpty && _present.last ? 0.5 : 0;
    var sum = 0.0;
    var count = 0;
    for (var i = 1; i < _tips.length; i++) {
      if (!_present[i] || !_present[i - 1]) continue;
      final a = _tips[i - 1];
      final b = _tips[i];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      sum += math.sqrt(dx * dx + dy * dy);
      count++;
    }
    if (count == 0) return 0;
    final meanDelta = sum / count;
    if (deltaLimit <= 0) return 0;
    final ratio = (meanDelta / deltaLimit).clamp(0.0, 2.0);
    return (1.0 - ratio / 2.0).clamp(0.0, 1.0).toDouble();
  }
}

/// Fuses calibrated frame into per-source confidence (IDS weakest-link).
final class SieConfidenceFusion {
  /// Creates fusion helper.
  const SieConfidenceFusion();

  /// Evaluate sources for [frame].
  SieConfidenceSources fuse({
    required SieCalibratedFrameSnapshot frame,
    required double temporalStability,
    required double trackingContinuity,
    required SieConfidenceThresholds thresholds,
  }) {
    final hand = frame.primaryHand;
    if (hand == null || hand.landmarks.isEmpty) {
      return SieConfidenceSources(
        vision: 0,
        landmarkQuality: 0,
        landmarkCompleteness: 0,
        calibrationValidity: _calibrationScore(frame),
        temporalStability: temporalStability,
        trackingContinuity: trackingContinuity,
      );
    }

    final vision = _clamp01(
      math.min(hand.handConfidence, hand.handednessScore),
    );

    final completeness = _clamp01(hand.landmarks.length / 21.0);

    var visSum = 0.0;
    var visN = 0;
    var dead = 0;
    var rest = 0;
    for (final lm in hand.landmarks) {
      if (lm.visibility != null) {
        visSum += lm.visibility!;
        visN++;
      }
      if (lm.presence != null) {
        visSum += lm.presence!;
        visN++;
      }
      if (lm.inDeadZone) dead++;
      if (lm.inRestZone) rest++;
    }
    final visScore = visN == 0 ? 0.85 : _clamp01(visSum / visN);
    final deadPenalty = 1.0 - (dead / hand.landmarks.length) * 0.5;
    final restPenalty = rest > hand.landmarks.length / 2 ? 0.7 : 1.0;
    var landmarkQuality = _clamp01(visScore * deadPenalty * restPenalty);
    // Policy floor: never report quality below invalidFloor when landmarks exist.
    if (landmarkQuality < thresholds.invalidFloor) {
      landmarkQuality = thresholds.invalidFloor;
    }

    return SieConfidenceSources(
      vision: vision,
      landmarkQuality: landmarkQuality,
      landmarkCompleteness: completeness,
      calibrationValidity: _calibrationScore(frame),
      temporalStability: _clamp01(temporalStability),
      trackingContinuity: _clamp01(trackingContinuity),
    );
  }

  static double _calibrationScore(SieCalibratedFrameSnapshot frame) {
    final p = frame.profile;
    if (!p.isValid) return 0.2;
    if (p.isIdentity) return 0.75;
    if (p.validated) return 1.0;
    return 0.85;
  }

  static double _clamp01(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return v.clamp(0.0, 1.0).toDouble();
  }
}

/// EMA smoother with spike suppression.
final class SieConfidenceSmoother {
  /// Creates smoother.
  SieConfidenceSmoother({this.alpha = 0.35});

  /// EMA alpha.
  final double alpha;

  double? _value;

  /// Reset.
  void reset() => _value = null;

  /// Smooth [raw], suppressing spikes larger than [spikeLimit].
  double update(double raw, double spikeLimit) {
    if (raw.isNaN || raw.isInfinite) {
      return _value ?? 0;
    }
    final prev = _value;
    if (prev == null) {
      _value = raw.clamp(0.0, 1.0).toDouble();
      return _value!;
    }
    var sample = raw.clamp(0.0, 1.0).toDouble();
    if ((sample - prev).abs() > spikeLimit) {
      // Soften spike toward previous rather than hiding genuine drops entirely.
      sample = prev + (sample - prev).sign * spikeLimit;
    }
    _value = prev + alpha * (sample - prev);
    return _value!.clamp(0.0, 1.0).toDouble();
  }
}
