import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_classifier.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// G01 OpenHandPoint classifier.
final class SieOpenHandPointClassifier implements SieGestureClassifier {
  /// Creates classifier.
  SieOpenHandPointClassifier();

  SieGesturePhase _phase = SieGesturePhase.idle;
  double? _stableSinceMs;
  int _enterStreak = 0;
  int _exitStreak = 0;

  @override
  void reset() {
    _phase = SieGesturePhase.idle;
    _stableSinceMs = null;
    _enterStreak = 0;
    _exitStreak = 0;
  }

  @override
  SieGestureHypothesis? step(SieGestureStepContext ctx) {
    if (!ctx.features.valid || !ctx.mayConsume) {
      if (_phase != SieGesturePhase.idle) {
        reset();
        return SieGestureHypothesis(
          kind: SieGestureKind.openHandPoint,
          phase: SieGesturePhase.released,
          confidence: ctx.overallConfidence,
          priority: 7,
          emit: true,
        );
      }
      return null;
    }

    final t = ctx.t;
    final open = ctx.features.openness >= 0.35 &&
        ctx.features.pinchDistance >= t.openHandPinchMin * 0.85 &&
        ctx.features.fistCurl > t.fistCurlMax;
    final now = ctx.timestampMs;

    if (open) {
      _exitStreak = 0;
      _enterStreak++;
      _stableSinceMs ??= now;
      final stableMs = now - _stableSinceMs!;
      if (_enterStreak >= t.enterFrames && stableMs >= t.pointStableMs) {
        final wasIdle = _phase == SieGesturePhase.idle ||
            _phase == SieGesturePhase.candidate;
        _phase = SieGesturePhase.maintained;
        return SieGestureHypothesis(
          kind: SieGestureKind.openHandPoint,
          phase: wasIdle
              ? SieGesturePhase.recognized
              : SieGesturePhase.maintained,
          confidence: (ctx.overallConfidence * 0.6 + ctx.features.openness * 0.4)
              .clamp(0.0, 1.0)
              .toDouble(),
          priority: 7,
          durationMs: stableMs,
          // Emit every maintained frame so Intent gets a fresh tip position.
          emit: true,
        );
      }
      _phase = SieGesturePhase.candidate;
      return SieGestureHypothesis(
        kind: SieGestureKind.openHandPoint,
        phase: SieGesturePhase.candidate,
        confidence: ctx.overallConfidence * 0.5,
        priority: 7,
        emit: false,
      );
    }

    _enterStreak = 0;
    _stableSinceMs = null;
    if (_phase == SieGesturePhase.maintained ||
        _phase == SieGesturePhase.recognized) {
      _exitStreak++;
      if (_exitStreak >= t.exitFrames) {
        reset();
        return SieGestureHypothesis(
          kind: SieGestureKind.openHandPoint,
          phase: SieGesturePhase.released,
          confidence: ctx.overallConfidence,
          priority: 7,
          emit: true,
        );
      }
    }
    return null;
  }
}

/// G07 FistCancel classifier.
final class SieFistCancelClassifier implements SieGestureClassifier {
  /// Creates classifier.
  SieFistCancelClassifier();

  double? _sinceMs;
  int _streak = 0;

  @override
  void reset() {
    _sinceMs = null;
    _streak = 0;
  }

  @override
  SieGestureHypothesis? step(SieGestureStepContext ctx) {
    if (!ctx.features.valid || !ctx.mayConsume || ctx.commitsSuppressed) {
      reset();
      return null;
    }
    final t = ctx.t;
    // Pinch tips-together is not a fist — leave pinch family alone.
    if (ctx.features.pinchDistance <= t.pinchArmEnter &&
        ctx.features.openness >= 0.18) {
      reset();
      return null;
    }
    final fist = ctx.features.fistCurl <= t.fistCurlMax &&
        ctx.features.pinchDistance <= t.fistPinchMax &&
        // Don't steal an in-progress pinch (tips together ≠ full fist).
        ctx.features.openness < 0.22;
    if (!fist) {
      reset();
      return null;
    }
    _streak++;
    _sinceMs ??= ctx.timestampMs;
    final dur = ctx.timestampMs - _sinceMs!;
    if (_streak >= t.enterFrames && dur >= t.fistMinMs) {
      final conf = (1.0 - ctx.features.fistCurl / (t.fistCurlMax + 1e-6))
          .clamp(0.0, 1.0)
          .toDouble();
      reset();
      return SieGestureHypothesis(
        kind: SieGestureKind.fistCancel,
        phase: SieGesturePhase.recognized,
        confidence: (0.5 * ctx.overallConfidence + 0.5 * conf)
            .clamp(0.0, 1.0)
            .toDouble(),
        priority: 3,
        durationMs: dur,
        emit: true,
      );
    }
    return SieGestureHypothesis(
      kind: SieGestureKind.fistCancel,
      phase: SieGesturePhase.candidate,
      confidence: ctx.overallConfidence * 0.4,
      priority: 3,
      emit: false,
    );
  }
}

/// G06 ScrollIntent classifier (emits only; does not scroll).
///
/// Mid-air scroll uses **stroke latching**: once a vertical stroke starts,
/// only that direction scrolls. The return motion (hand going back) is
/// ignored so the page does not undo itself.
final class SieScrollIntentClassifier implements SieGestureClassifier {
  /// Creates classifier.
  SieScrollIntentClassifier();

  SieGesturePhase _phase = SieGesturePhase.idle;
  double? _sinceMs;
  SieSpatialPoint2D? _prevScreenTip;
  /// Locked stroke direction: -1 up, +1 down, 0 none.
  int _strokeSign = 0;
  /// True while ignoring the return half of a stroke.
  bool _returning = false;

  /// Min screen-pixel motion to start / continue a stroke.
  static const double _startPx = 4;
  /// Amplify finger motion → page scroll (mid-air needs more travel).
  static const double _pageGain = 3.2;
  /// Near-stop threshold to end a stroke / clear return latch.
  static const double _stopPx = 1.2;

  @override
  void reset() {
    _phase = SieGesturePhase.idle;
    _sinceMs = null;
    _prevScreenTip = null;
    _strokeSign = 0;
    _returning = false;
  }

  @override
  SieGestureHypothesis? step(SieGestureStepContext ctx) {
    if (!ctx.features.valid || !ctx.mayConsume || ctx.commitsSuppressed) {
      if (_phase == SieGesturePhase.active) {
        reset();
        return SieGestureHypothesis(
          kind: SieGestureKind.scrollIntent,
          phase: SieGesturePhase.completed,
          confidence: ctx.overallConfidence,
          priority: 5,
          emit: true,
        );
      }
      reset();
      return null;
    }

    final t = ctx.t;
    // Prefer open-ish hand for scroll (not pinched).
    if (ctx.features.pinchDistance < t.pinchArmEnter) {
      if (_phase == SieGesturePhase.active) {
        final done = SieGestureHypothesis(
          kind: SieGestureKind.scrollIntent,
          phase: SieGesturePhase.completed,
          confidence: ctx.overallConfidence,
          priority: 5,
          emit: true,
          durationMs: _sinceMs == null ? 0 : ctx.timestampMs - _sinceMs!,
        );
        reset();
        return done;
      }
      reset();
      return null;
    }

    final tip = ctx.features.indexTipScreen;
    final usable = tip.x.abs() > 1 || tip.y.abs() > 1;
    var screenDy = 0.0;
    if (usable && _prevScreenTip != null) {
      screenDy = tip.y - _prevScreenTip!.y;
    }
    if (usable) {
      _prevScreenTip = tip;
    }

    final absDy = screenDy.abs();

    // Hand nearly stopped → end stroke so next intentional move can reverse.
    if (absDy < _stopPx) {
      if (_returning || _strokeSign != 0) {
        _strokeSign = 0;
        _returning = false;
        if (_phase == SieGesturePhase.active) {
          _phase = SieGesturePhase.idle;
          _sinceMs = null;
          return SieGestureHypothesis(
            kind: SieGestureKind.scrollIntent,
            phase: SieGesturePhase.completed,
            confidence: ctx.overallConfidence * 0.5,
            priority: 5,
            emit: false,
          );
        }
      }
      return null;
    }

    // Return half of stroke: ignore until stop clears latch.
    if (_returning) {
      return null;
    }

    final sign = screenDy > 0 ? 1 : -1;

    if (_strokeSign == 0) {
      if (absDy < _startPx) return null;
      _sinceMs ??= ctx.timestampMs;
      final dur = ctx.timestampMs - _sinceMs!;
      if (dur < t.scrollMinMs) {
        _phase = SieGesturePhase.candidate;
        return null;
      }
      _strokeSign = sign;
      _phase = SieGesturePhase.active;
      return _emit(
        ctx: ctx,
        screenDy: screenDy,
        phase: SieGesturePhase.recognized,
        dur: dur,
      );
    }

    // Opposite direction while stroke locked = return motion → ignore.
    if (sign != _strokeSign) {
      if (absDy >= _startPx) {
        _returning = true;
      }
      return null;
    }

    // Same direction — keep scrolling.
    final dur = _sinceMs == null ? 0.0 : ctx.timestampMs - _sinceMs!;
    _phase = SieGesturePhase.active;
    return _emit(
      ctx: ctx,
      screenDy: screenDy,
      phase: SieGesturePhase.active,
      dur: dur,
    );
  }

  SieGestureHypothesis _emit({
    required SieGestureStepContext ctx,
    required double screenDy,
    required SieGesturePhase phase,
    required double dur,
  }) {
    // axisDelta is already logical pixels (page travel).
    final pageDy = screenDy * _pageGain;
    return SieGestureHypothesis(
      kind: SieGestureKind.scrollIntent,
      phase: phase,
      confidence: (ctx.overallConfidence * 0.75 + 0.2).clamp(0.0, 1.0),
      priority: 5,
      axisDelta: pageDy,
      durationMs: dur,
      emit: pageDy.abs() >= 2,
    );
  }
}

/// G08 SwipeNavigation — feature-flagged, off by default.
final class SieSwipeNavigationClassifier implements SieGestureClassifier {
  /// Creates classifier.
  SieSwipeNavigationClassifier();

  double? _startX;
  double? _startMs;

  @override
  void reset() {
    _startX = null;
    _startMs = null;
  }

  @override
  SieGestureHypothesis? step(SieGestureStepContext ctx) {
    if (!ctx.policy.swipeNavigationEnabled) {
      reset();
      return null;
    }
    if (!ctx.features.valid ||
        !ctx.mayConsume ||
        ctx.commitsSuppressed ||
        !ctx.gestureReady) {
      reset();
      return null;
    }
    final t = ctx.t;
    // Must not be pinching.
    if (ctx.features.pinchDistance < t.pinchArmEnter) {
      reset();
      return null;
    }

    final x = ctx.features.indexTip.x;
    final vx = ctx.features.tipVelocity.x;
    _startX ??= x;
    _startMs ??= ctx.timestampMs;
    final dx = x - _startX!;
    final dur = ctx.timestampMs - _startMs!;
    if (dur > 500) {
      reset();
      return null;
    }
    if (dx.abs() >= t.swipeMinDistance &&
        vx.abs() >= t.swipeMinVelocity &&
        dur >= 40) {
      final conf = (dx.abs() / t.swipeMinDistance).clamp(0.0, 1.0).toDouble();
      reset();
      return SieGestureHypothesis(
        kind: SieGestureKind.swipeNavigation,
        phase: SieGesturePhase.recognized,
        confidence: (0.5 * ctx.overallConfidence + 0.5 * conf)
            .clamp(0.0, 1.0)
            .toDouble(),
        priority: 6,
        axisDelta: dx,
        durationMs: dur,
        emit: true,
      );
    }
    return null;
  }
}

/// G09 DwellSelect — accessibility only.
final class SieDwellSelectClassifier implements SieGestureClassifier {
  /// Creates classifier.
  SieDwellSelectClassifier();

  double? _sinceMs;
  double _progress = 0;

  /// Dwell progress.
  double get progress => _progress;

  @override
  void reset() {
    _sinceMs = null;
    _progress = 0;
  }

  @override
  SieGestureHypothesis? step(SieGestureStepContext ctx) {
    if (!ctx.policy.dwellSelectEnabled) {
      reset();
      return null;
    }
    if (!ctx.features.valid ||
        !ctx.mayConsume ||
        ctx.commitsSuppressed ||
        !ctx.gestureReady) {
      reset();
      return null;
    }
    final t = ctx.t;
    // Stable tip (low velocity) for dwell.
    final speed = ctx.features.tipVelocity.x.abs() +
        ctx.features.tipVelocity.y.abs();
    final stable = speed < t.scrollActivateVelocity * 0.5 &&
        ctx.features.pinchDistance >= t.openHandPinchMin * 0.8;
    if (!stable) {
      reset();
      return null;
    }
    _sinceMs ??= ctx.timestampMs;
    final dur = ctx.timestampMs - _sinceMs!;
    _progress = (dur / t.dwellMs).clamp(0.0, 1.0).toDouble();
    if (_progress >= 1.0) {
      reset();
      return SieGestureHypothesis(
        kind: SieGestureKind.dwellSelect,
        phase: SieGesturePhase.recognized,
        confidence: ctx.overallConfidence,
        priority: 4,
        progress: 1,
        durationMs: dur,
        emit: true,
      );
    }
    return SieGestureHypothesis(
      kind: SieGestureKind.dwellSelect,
      phase: SieGesturePhase.candidate,
      confidence: ctx.overallConfidence * 0.5,
      priority: 4,
      progress: _progress,
      durationMs: dur,
      emit: false,
    );
  }
}
