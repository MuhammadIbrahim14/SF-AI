import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_classifier.dart';

/// Unified pinch family FSM: Idle → Arming → Committed → Held → Released → Idle.
///
/// Emits PinchArm / PinchCommit / PinchHold / PinchRelease events per IDS G02–G05.
final class SiePinchFamilyClassifier implements SieGestureClassifier {
  /// Creates classifier.
  SiePinchFamilyClassifier();

  SieGesturePhase _phase = SieGesturePhase.idle;
  double? _armStartedMs;
  double? _commitZoneStartedMs;
  double? _lastCommitMs;
  double _armProgress = 0;
  int _armEnterStreak = 0;
  int _releaseStreak = 0;

  /// Arming progress [0,1].
  double get armingProgress => _armProgress;

  /// Current phase.
  SieGesturePhase get phase => _phase;

  @override
  void reset() {
    _phase = SieGesturePhase.idle;
    _armStartedMs = null;
    _commitZoneStartedMs = null;
    _armProgress = 0;
    _armEnterStreak = 0;
    _releaseStreak = 0;
  }

  @override
  SieGestureHypothesis? step(SieGestureStepContext ctx) {
    if (!ctx.features.valid || !ctx.mayConsume) {
      if (_phase != SieGesturePhase.idle) {
        final cancelled = SieGestureHypothesis(
          kind: SieGestureKind.pinchRelease,
          phase: SieGesturePhase.cancelled,
          confidence: ctx.overallConfidence,
          priority: 4,
          durationMs: _duration(ctx),
          emit: _phase == SieGesturePhase.arming ||
              _phase == SieGesturePhase.committed ||
              _phase == SieGesturePhase.held,
        );
        reset();
        return cancelled.emit ? cancelled : null;
      }
      return null;
    }

    final t = ctx.t;
    final d = ctx.features.pinchDistance;
    final now = ctx.timestampMs;

    // Allow commits once the frame is consumable. gestureReady latch is a
    // nicety for precision mode — waiting on it made pinch feel broken on web.
    final allowCommit = ctx.mayConsume && !ctx.commitsSuppressed;

    switch (_phase) {
      case SieGesturePhase.idle:
      case SieGesturePhase.candidate:
      case SieGesturePhase.released:
      case SieGesturePhase.cancelled:
      case SieGesturePhase.recognized:
      case SieGesturePhase.maintained:
      case SieGesturePhase.active:
      case SieGesturePhase.completed:
        _phase = SieGesturePhase.idle;
        if (d <= t.pinchArmEnter) {
          _armEnterStreak++;
          if (_armEnterStreak >= t.enterFrames) {
            _phase = SieGesturePhase.arming;
            _armStartedMs = now;
            _armProgress = 0;
            return SieGestureHypothesis(
              kind: SieGestureKind.pinchArm,
              phase: SieGesturePhase.arming,
              confidence: _pinchConf(ctx, d),
              priority: 4,
              progress: 0,
              durationMs: 0,
              emit: true,
            );
          }
        } else {
          _armEnterStreak = 0;
        }
        return null;

      case SieGesturePhase.arming:
        if (d > t.pinchArmExit) {
          _phase = SieGesturePhase.idle;
          _armStartedMs = null;
          _armProgress = 0;
          _armEnterStreak = 0;
          return SieGestureHypothesis(
            kind: SieGestureKind.pinchArm,
            phase: SieGesturePhase.cancelled,
            confidence: _pinchConf(ctx, d),
            priority: 4,
            emit: true,
            durationMs: _duration(ctx),
          );
        }
        final armElapsed = now - (_armStartedMs ?? now);
        _armProgress = (armElapsed / t.armMinMs).clamp(0.0, 1.0).toDouble();

        if (d <= t.pinchCommitEnter) {
          _commitZoneStartedMs ??= now;
        } else {
          _commitZoneStartedMs = null;
        }

        final commitReady = allowCommit &&
            _armProgress >= 1.0 &&
            _commitZoneStartedMs != null &&
            (now - _commitZoneStartedMs!) >= t.commitMinMs &&
            (_lastCommitMs == null ||
                (now - _lastCommitMs!) >= t.reclickMs);

        if (commitReady) {
          _phase = SieGesturePhase.committed;
          _lastCommitMs = now;
          _armProgress = 1;
          return SieGestureHypothesis(
            kind: SieGestureKind.pinchCommit,
            phase: SieGesturePhase.committed,
            confidence: _pinchConf(ctx, d),
            priority: 4,
            progress: 1,
            durationMs: armElapsed,
            emit: true,
          );
        }

        return SieGestureHypothesis(
          kind: SieGestureKind.pinchArm,
          phase: SieGesturePhase.arming,
          confidence: _pinchConf(ctx, d),
          priority: 4,
          progress: _armProgress,
          durationMs: armElapsed,
          emit: false,
        );

      case SieGesturePhase.committed:
        _phase = SieGesturePhase.held;
        return SieGestureHypothesis(
          kind: SieGestureKind.pinchHold,
          phase: SieGesturePhase.held,
          confidence: _pinchConf(ctx, d),
          priority: 4,
          progress: 1,
          durationMs: _duration(ctx),
          emit: true,
        );

      case SieGesturePhase.held:
        final holdDist = t.pinchHoldEnter;
        if (d <= holdDist) {
          // Still firmly pinched — reset release streak.
          _releaseStreak = 0;
          return SieGestureHypothesis(
            kind: SieGestureKind.pinchHold,
            phase: SieGesturePhase.held,
            confidence: _pinchConf(ctx, d),
            priority: 4,
            progress: 1,
            durationMs: _duration(ctx),
            // Don't flood every frame — moveCursor already tracks tip.
            // Emitting every frame was converting clicks into drags.
            emit: false,
          );
        }

        // Opening past the hold band: count toward release.
        _releaseStreak++;
        if (_releaseStreak >= t.exitFrames) {
          _phase = SieGesturePhase.released;
          return SieGestureHypothesis(
            kind: SieGestureKind.pinchRelease,
            phase: SieGesturePhase.released,
            confidence: _pinchConf(ctx, d),
            priority: 4,
            durationMs: _duration(ctx),
            emit: true,
          );
        }

        return SieGestureHypothesis(
          kind: SieGestureKind.pinchHold,
          phase: SieGesturePhase.held,
          confidence: _pinchConf(ctx, d),
          priority: 4,
          durationMs: _duration(ctx),
          emit: false,
        );
    }
  }

  /// Advance released → idle on subsequent frame.
  void settleRelease() {
    if (_phase == SieGesturePhase.released) {
      _phase = SieGesturePhase.idle;
      _armStartedMs = null;
      _commitZoneStartedMs = null;
      _armProgress = 0;
      _armEnterStreak = 0;
      _releaseStreak = 0;
    }
  }

  double _duration(SieGestureStepContext ctx) {
    if (_armStartedMs == null) return 0;
    return ctx.timestampMs - _armStartedMs!;
  }

  double _pinchConf(SieGestureStepContext ctx, double d) {
    final t = ctx.t;
    final closeness = (1.0 - (d / (t.pinchArmExit + 1e-6))).clamp(0.0, 1.0);
    return (0.5 * ctx.overallConfidence + 0.5 * closeness)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}
