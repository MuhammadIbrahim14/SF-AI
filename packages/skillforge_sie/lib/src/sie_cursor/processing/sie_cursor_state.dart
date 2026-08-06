import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';

/// Resolves cursor state from intents + tracking (IDS-aligned).
final class SieCursorStateResolver {
  /// Creates resolver.
  const SieCursorStateResolver();

  /// Resolve state for this frame.
  SieCursorState resolve({
    required SieTrackingReliabilityState tracking,
    required SieInteractionMode mode,
    required List<SieIntentEvent> actionable,
    required bool hasPosition,
    required bool paused,
  }) {
    if (paused || mode == SieInteractionMode.paused) {
      return SieCursorState.paused;
    }
    if (tracking == SieTrackingReliabilityState.disabled ||
        tracking == SieTrackingReliabilityState.error) {
      return SieCursorState.hidden;
    }
    if (tracking == SieTrackingReliabilityState.lostTracking) {
      return SieCursorState.lostTracking;
    }
    if (tracking == SieTrackingReliabilityState.recovering) {
      return SieCursorState.recovering;
    }
    if (!hasPosition && tracking == SieTrackingReliabilityState.idle) {
      return SieCursorState.hidden;
    }

    // Intent-driven modes take precedence.
    for (final e in actionable) {
      switch (e.kind) {
        case SieIntentKind.beginDrag:
        case SieIntentKind.updateDrag:
          return SieCursorState.dragging;
        case SieIntentKind.selectHold:
          return SieCursorState.pressed;
        case SieIntentKind.select:
          if (e.phase == SieIntentPhase.candidate ||
              e.phase == SieIntentPhase.ready) {
            return SieCursorState.armed;
          }
          if (e.phase == SieIntentPhase.active) {
            return SieCursorState.pressed;
          }
        case SieIntentKind.dwellSelect:
          return SieCursorState.armed;
        case SieIntentKind.scrollDelta:
          return SieCursorState.scrolling;
        case SieIntentKind.hoverEnter:
          return SieCursorState.hovering;
        default:
          break;
      }
    }

    if (mode == SieInteractionMode.dragging) return SieCursorState.dragging;
    if (mode == SieInteractionMode.selecting) return SieCursorState.pressed;
    if (mode == SieInteractionMode.scrolling) return SieCursorState.scrolling;
    if (mode == SieInteractionMode.hovering) return SieCursorState.hovering;
    if (mode == SieInteractionMode.moving) return SieCursorState.moving;

    final moving = actionable.any(
      (e) =>
          e.kind == SieIntentKind.moveCursor &&
          e.phase == SieIntentPhase.active,
    );
    if (moving) return SieCursorState.moving;

    return hasPosition ? SieCursorState.visible : SieCursorState.hidden;
  }
}

/// Manages opacity / visibility modes deterministically.
final class SieCursorVisibilityController {
  /// Creates controller.
  SieCursorVisibilityController();

  DateTime? _fadeStart;
  SieCursorVisibilityMode _mode = SieCursorVisibilityMode.hidden;
  double _opacity = 0;

  /// Current mode.
  SieCursorVisibilityMode get mode => _mode;

  /// Current opacity.
  double get opacity => _opacity;

  /// Reset.
  void reset() {
    _fadeStart = null;
    _mode = SieCursorVisibilityMode.hidden;
    _opacity = 0;
  }

  /// Update visibility given state + config + now.
  ({SieCursorVisibilityMode mode, double opacity}) update({
    required SieCursorState state,
    required SieCursorMotionConfig config,
    required DateTime now,
    required bool movedThisFrame,
    required DateTime? lastMoveAt,
  }) {
    switch (state) {
      case SieCursorState.hidden:
        return _setHidden();
      case SieCursorState.paused:
        return _fadeToward(0, config.fadeOutMs, now, fadingOut: true);
      case SieCursorState.lostTracking:
        _mode = SieCursorVisibilityMode.faded;
        _opacity = config.lostTrackingFadeOpacity;
        return (mode: _mode, opacity: _opacity);
      case SieCursorState.recovering:
        _mode = SieCursorVisibilityMode.recovering;
        _opacity = 0.7;
        return (mode: _mode, opacity: _opacity);
      case SieCursorState.visible:
      case SieCursorState.moving:
      case SieCursorState.hovering:
      case SieCursorState.armed:
      case SieCursorState.pressed:
      case SieCursorState.dragging:
      case SieCursorState.scrolling:
        // Idle timeout.
        if (!movedThisFrame &&
            config.idleHideMs > 0 &&
            lastMoveAt != null) {
          final idle = now.difference(lastMoveAt).inMilliseconds;
          if (idle >= config.idleHideMs) {
            return _fadeToward(0, config.fadeOutMs, now, fadingOut: true);
          }
        }
        return _fadeToward(1, config.fadeInMs, now, fadingOut: false);
    }
  }

  ({SieCursorVisibilityMode mode, double opacity}) _setHidden() {
    _mode = SieCursorVisibilityMode.hidden;
    _opacity = 0;
    _fadeStart = null;
    return (mode: _mode, opacity: _opacity);
  }

  ({SieCursorVisibilityMode mode, double opacity}) _fadeToward(
    double target,
    double durationMs,
    DateTime now, {
    required bool fadingOut,
  }) {
    if (durationMs <= 0) {
      _opacity = target;
      _mode = target <= 0
          ? SieCursorVisibilityMode.hidden
          : SieCursorVisibilityMode.visible;
      return (mode: _mode, opacity: _opacity);
    }
    _fadeStart ??= now;
    final elapsed = now.difference(_fadeStart!).inMilliseconds.toDouble();
    final t = (elapsed / durationMs).clamp(0.0, 1.0);
    if (fadingOut) {
      _opacity = (1 - t).clamp(0.0, 1.0) * (_opacity <= 0 ? 0 : 1);
      // Blend from current toward 0.
      _opacity = (1.0 - t);
      _mode = t >= 1
          ? SieCursorVisibilityMode.hidden
          : SieCursorVisibilityMode.fadingOut;
    } else {
      _opacity = t;
      _mode = t >= 1
          ? SieCursorVisibilityMode.visible
          : SieCursorVisibilityMode.fadingIn;
    }
    if (t >= 1) _fadeStart = null;
    return (mode: _mode, opacity: _opacity);
  }
}

/// Lightweight animation phase (frame-rate independent).
final class SieCursorAnimator {
  /// Creates animator.
  SieCursorAnimator();

  double _phase = 0;
  DateTime? _last;

  /// Current phase [0,1].
  double get phase => _phase;

  /// Reset.
  void reset() {
    _phase = 0;
    _last = null;
  }

  /// Advance; returns 0 when reduced motion.
  double advance({
    required DateTime now,
    required SieCursorState state,
    required bool reducedMotion,
  }) {
    if (reducedMotion) {
      _phase = 0;
      _last = now;
      return 0;
    }
    final periodMs = switch (state) {
      SieCursorState.hovering => 1200.0,
      SieCursorState.armed => 800.0,
      SieCursorState.pressed => 400.0,
      SieCursorState.dragging => 1000.0,
      SieCursorState.recovering => 900.0,
      _ => 0.0,
    };
    if (periodMs <= 0) {
      _phase = 0;
      _last = now;
      return 0;
    }
    final prev = _last ?? now;
    final dt = now.difference(prev).inMilliseconds.clamp(0, 100);
    _last = now;
    _phase = (_phase + dt / periodMs) % 1.0;
    return _phase;
  }
}
