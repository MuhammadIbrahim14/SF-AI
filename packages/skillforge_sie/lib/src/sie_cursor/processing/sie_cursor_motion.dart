import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Adaptive low-pass motion filter with jitter / spike suppression.
final class SieCursorMotionFilter {
  /// Creates filter.
  SieCursorMotionFilter({SieCursorMotionConfig config = SieCursorMotionConfig.standard})
      : _config = config;

  SieCursorMotionConfig _config;
  SieSpatialPoint2D? _smoothed;
  double _lastAlpha = 0.35;

  /// Effective alpha last used.
  double get lastAlpha => _lastAlpha;

  /// Update config.
  void setConfig(SieCursorMotionConfig config) => _config = config;

  /// Reset.
  void reset() {
    _smoothed = null;
    _lastAlpha = _config.smoothingAlpha;
  }

  /// Filter raw sample → smoothed position.
  SieSpatialPoint2D filter(SieSpatialPoint2D raw) {
    final prev = _smoothed;
    if (prev == null) {
      _smoothed = raw;
      _lastAlpha = 1;
      return raw;
    }

    var dx = raw.x - prev.x;
    var dy = raw.y - prev.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Jitter suppression.
    if (dist < _config.jitterEpsilon) {
      _lastAlpha = _config.minSmoothingAlpha;
      return prev;
    }

    // Spike clamp.
    if (dist > _config.spikeThreshold) {
      final scale = _config.spikeThreshold / dist;
      dx *= scale;
      dy *= scale;
    }

    var alpha = _config.smoothingAlpha;
    if (_config.velocityAdaptive) {
      // Faster motion → higher alpha (more responsive).
      final t = (dist / 40).clamp(0.0, 1.0);
      alpha = _config.minSmoothingAlpha +
          (_config.maxSmoothingAlpha - _config.minSmoothingAlpha) * t;
      // Blend with base.
      alpha = (alpha + _config.smoothingAlpha) * 0.5;
      alpha = alpha.clamp(_config.minSmoothingAlpha, _config.maxSmoothingAlpha);
    }
    _lastAlpha = alpha;

    final next = SieSpatialPoint2D(
      prev.x + dx * alpha,
      prev.y + dy * alpha,
    );
    _smoothed = next;
    return next;
  }

  /// Current smoothed (or null).
  SieSpatialPoint2D? get current => _smoothed;
}

/// Conservative velocity-based prediction with clamping.
final class SieCursorPredictor {
  /// Creates predictor.
  const SieCursorPredictor();

  /// Predict offset from velocity (px/ms). Disabled when [enabled] is false.
  SieSpatialPoint2D predict({
    required SieSpatialPoint2D velocity,
    required SieCursorMotionConfig config,
    required bool enabled,
  }) {
    if (!enabled || !config.predictionEnabled) {
      return SieSpatialPoint2D.zero;
    }
    final horizon = config.predictionHorizonMs;
    var ox = velocity.x * horizon;
    var oy = velocity.y * horizon;
    final mag = math.sqrt(ox * ox + oy * oy);
    if (mag > config.maxPredictionPx && mag > 0) {
      final s = config.maxPredictionPx / mag;
      ox *= s;
      oy *= s;
    }
    // Sudden reverse: if velocity is near zero, no prediction.
    if (mag < 0.01) return SieSpatialPoint2D.zero;
    return SieSpatialPoint2D(ox, oy);
  }
}

/// Soft acceleration / gain curves.
final class SieCursorAccelerator {
  /// Creates accelerator.
  const SieCursorAccelerator();

  /// Apply gain to delta from previous smoothed toward target.
  SieSpatialPoint2D applyGain({
    required SieSpatialPoint2D from,
    required SieSpatialPoint2D to,
    required SieCursorMotionConfig config,
    required SieCursorMotionProfileId profile,
    required bool armed,
  }) {
    final base = switch (profile) {
      SieCursorMotionProfileId.standard => config.accelerationGain,
      SieCursorMotionProfileId.precision => config.precisionGain,
      SieCursorMotionProfileId.fast =>
        armed ? config.accelerationGain : config.fastGain,
      SieCursorMotionProfileId.accessibility => config.accessibilityGain,
    };
    // Soft curve: gain approaches 1 for small deltas (precision).
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final soft = dist < 8 ? (0.7 + 0.3 * (dist / 8)) : 1.0;
    final gain = base * soft;
    return SieSpatialPoint2D(from.x + dx * gain, from.y + dy * gain);
  }
}

/// Magnetic snap with hysteresis — never teleports.
final class SieCursorSnapAssistance {
  /// Creates snapper.
  SieCursorSnapAssistance();

  String? _latchedId;

  /// Reset.
  void reset() => _latchedId = null;

  /// Current latch.
  String? get latchedId => _latchedId;

  /// Soft-pull toward nearest allowed target.
  ({SieSpatialPoint2D position, String? targetId, bool snapped}) apply({
    required SieSpatialPoint2D position,
    required List<SieCursorSnapTarget> targets,
    required SieCursorMotionConfig config,
    required bool allowed,
  }) {
    if (!allowed || targets.isEmpty) {
      _latchedId = null;
      return (position: position, targetId: null, snapped: false);
    }

    SieCursorSnapTarget? best;
    var bestDist = double.infinity;
    for (final t in targets) {
      if (!t.isLarge) continue;
      final r = t.radius ?? config.snapRadius;
      final engage = _latchedId == t.id ? r * config.snapReleaseHysteresis : r;
      final d = _dist(position, t.center);
      if (d <= engage && d < bestDist) {
        best = t;
        bestDist = d;
      }
    }

    if (best == null) {
      _latchedId = null;
      return (position: position, targetId: null, snapped: false);
    }

    _latchedId = best.id;
    final s = config.snapStrength.clamp(0.0, 1.0);
    // Soft pull — never jump to center.
    final next = SieSpatialPoint2D(
      position.x + (best.center.x - position.x) * s,
      position.y + (best.center.y - position.y) * s,
    );
    return (position: next, targetId: best.id, snapped: s > 0);
  }

  static double _dist(SieSpatialPoint2D a, SieSpatialPoint2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Screen clamp + edge resistance.
final class SieCursorBoundsClamp {
  /// Creates clamper.
  const SieCursorBoundsClamp();

  /// Clamp into usable display with optional edge resistance.
  ({SieSpatialPoint2D position, bool clamped}) clamp({
    required SieSpatialPoint2D position,
    required SieCursorDisplayBounds bounds,
    required SieCursorMotionConfig config,
  }) {
    if (!bounds.isValid) {
      return (position: position, clamped: false);
    }
    final m = config.safeMargin;
    final left = bounds.marginLeft + m;
    final top = bounds.marginTop + m;
    final right = bounds.width - bounds.marginRight - m;
    final bottom = bounds.height - bounds.marginBottom - m;
    if (right <= left || bottom <= top) {
      return (position: position, clamped: false);
    }

    var x = position.x;
    var y = position.y;
    var clamped = false;

    // Soft edge resistance before hard clamp.
    final resist = config.edgeResistance;
    final band = 12.0;
    if (resist > 0) {
      if (x < left + band) {
        final t = ((left + band) - x) / band;
        x += t * resist * 2;
      } else if (x > right - band) {
        final t = (x - (right - band)) / band;
        x -= t * resist * 2;
      }
      if (y < top + band) {
        final t = ((top + band) - y) / band;
        y += t * resist * 2;
      } else if (y > bottom - band) {
        final t = (y - (bottom - band)) / band;
        y -= t * resist * 2;
      }
    }

    if (x < left) {
      x = left;
      clamped = true;
    } else if (x > right) {
      x = right;
      clamped = true;
    }
    if (y < top) {
      y = top;
      clamped = true;
    } else if (y > bottom) {
      y = bottom;
      clamped = true;
    }
    return (position: SieSpatialPoint2D(x, y), clamped: clamped);
  }
}
