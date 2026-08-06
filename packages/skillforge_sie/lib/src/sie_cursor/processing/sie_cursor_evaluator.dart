import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_engine_status.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_cursor/processing/sie_cursor_motion.dart';
import 'package:skillforge_sie/src/sie_cursor/processing/sie_cursor_state.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Frame evaluation result.
final class SieCursorEvalResult {
  /// Creates result.
  const SieCursorEvalResult({
    required this.snapshot,
    required this.clamped,
    required this.snapped,
  });

  /// Snapshot.
  final SieCursorSnapshot snapshot;

  /// Whether clamped.
  final bool clamped;

  /// Whether snapped.
  final bool snapped;
}

/// Composes filter → accel → predict → snap → clamp → visibility → state.
final class SieCursorEvaluator {
  /// Creates evaluator.
  SieCursorEvaluator({SieCursorEngineConfig? config})
      : _config = config ?? const SieCursorEngineConfig(),
        _filter = SieCursorMotionFilter(
          config: (config ?? const SieCursorEngineConfig()).motion,
        ),
        _predictor = const SieCursorPredictor(),
        _accelerator = const SieCursorAccelerator(),
        _snap = SieCursorSnapAssistance(),
        _clamp = const SieCursorBoundsClamp(),
        _states = const SieCursorStateResolver(),
        _visibility = SieCursorVisibilityController(),
        _animator = SieCursorAnimator(),
        _model = SieCursorWorkingModel();

  SieCursorEngineConfig _config;
  final SieCursorMotionFilter _filter;
  final SieCursorPredictor _predictor;
  final SieCursorAccelerator _accelerator;
  final SieCursorSnapAssistance _snap;
  final SieCursorBoundsClamp _clamp;
  final SieCursorStateResolver _states;
  final SieCursorVisibilityController _visibility;
  final SieCursorAnimator _animator;
  final SieCursorWorkingModel _model;

  DateTime? _prevTimestamp;
  List<SieCursorSnapTarget> _targets = const [];

  /// Config.
  SieCursorEngineConfig get config => _config;

  /// Working model (tests).
  SieCursorWorkingModel get model => _model;

  /// Update config.
  void setConfig(SieCursorEngineConfig config) {
    _config = config;
    _filter.setConfig(config.motion);
  }

  /// Replace snap targets (host).
  void setSnapTargets(List<SieCursorSnapTarget> targets) {
    _targets = List.unmodifiable(targets);
  }

  /// Reset internal state.
  void reset() {
    _filter.reset();
    _snap.reset();
    _visibility.reset();
    _animator.reset();
    _prevTimestamp = null;
    _model
      ..position = SieSpatialPoint2D.zero
      ..rawPosition = SieSpatialPoint2D.zero
      ..velocity = SieSpatialPoint2D.zero
      ..state = SieCursorState.hidden
      ..opacity = 0
      ..visibility = SieCursorVisibilityMode.hidden
      ..hoverTargetId = null
      ..snapTargetId = null
      ..snapped = false
      ..lastMoveAt = null
      ..hoverSince = null
      ..animationPhase = 0;
  }

  /// Evaluate one intent frame.
  SieCursorEvalResult evaluate(SieIntentFrameSnapshot input) {
    final actionable = input.actionable;
    final tracking = _trackingFrom(actionable, input);
    final paused = input.mode == SieInteractionMode.paused ||
        actionable.any((e) => e.kind == SieIntentKind.pauseSie);

    // Extract motion sample + hover.
    SieSpatialPoint2D? raw;
    String? hoverId = _model.hoverTargetId;
    var armed = false;
    for (final e in actionable) {
      if (e.position != null &&
          (e.kind == SieIntentKind.moveCursor ||
              e.kind == SieIntentKind.beginDrag ||
              e.kind == SieIntentKind.updateDrag ||
              e.kind == SieIntentKind.select ||
              e.kind == SieIntentKind.selectHold ||
              e.kind == SieIntentKind.hoverEnter)) {
        raw = e.position;
      }
      if (e.kind == SieIntentKind.hoverEnter) {
        hoverId = e.targetId ?? hoverId;
      } else if (e.kind == SieIntentKind.hoverExit) {
        if (e.targetId == hoverId) hoverId = null;
      }
      if (e.kind == SieIntentKind.select &&
          (e.phase == SieIntentPhase.candidate ||
              e.phase == SieIntentPhase.ready)) {
        armed = true;
      }
      if (e.kind == SieIntentKind.dwellSelect) armed = true;
    }
    // Prefer any position on the frame.
    if (raw == null) {
      for (final e in actionable) {
        if (e.position != null) {
          raw = e.position;
          break;
        }
      }
    }

    final dtMs = _deltaMs(input.timestamp);
    var moved = false;
    var predictionOffset = SieSpatialPoint2D.zero;
    var clamped = false;
    var snapped = false;
    String? snapId;

    if (raw != null &&
        _isFinite(raw) &&
        tracking != SieTrackingReliabilityState.lostTracking &&
        tracking != SieTrackingReliabilityState.disabled &&
        !paused) {
      _model.rawPosition = raw;

      // 1) Smooth
      var smoothed = _filter.filter(raw);

      // 2) Soft acceleration toward smoothed from previous model pos
      smoothed = _accelerator.applyGain(
        from: _model.position == SieSpatialPoint2D.zero &&
                _filter.current == smoothed
            ? smoothed
            : _model.position,
        to: smoothed,
        config: _config.motion,
        profile: _config.motionProfile,
        armed: armed,
      );

      // Velocity
      if (dtMs > 0) {
        final vx = (smoothed.x - _model.position.x) / dtMs;
        final vy = (smoothed.y - _model.position.y) / dtMs;
        _model.velocity = SieSpatialPoint2D(vx, vy);
      }

      // 3) Prediction (disabled recovering / lost / degraded)
      final predictOk = tracking != SieTrackingReliabilityState.recovering &&
          tracking != SieTrackingReliabilityState.lostTracking &&
          tracking != SieTrackingReliabilityState.degraded;
      predictionOffset = _predictor.predict(
        velocity: _model.velocity,
        config: _config.motion,
        enabled: predictOk,
      );
      var pos = SieSpatialPoint2D(
        smoothed.x + predictionOffset.x,
        smoothed.y + predictionOffset.y,
      );

      // 4) Snap
      final snapResult = _snap.apply(
        position: pos,
        targets: _targets,
        config: _config.motion,
        allowed: _config.snapAllowed,
      );
      pos = snapResult.position;
      snapId = snapResult.targetId;
      snapped = snapResult.snapped;

      // 5) Clamp
      final clampResult = _clamp.clamp(
        position: pos,
        bounds: _config.bounds,
        config: _config.motion,
      );
      pos = clampResult.position;
      clamped = clampResult.clamped;

      moved = (pos.x - _model.position.x).abs() > 0.01 ||
          (pos.y - _model.position.y).abs() > 0.01;
      _model.position = pos;
      if (moved) _model.lastMoveAt = input.timestamp;
    } else if (raw != null && !_isFinite(raw)) {
      // Invalid coordinates — keep last position.
    }

    _model.hoverTargetId = hoverId;
    _model.snapTargetId = snapId;
    _model.snapped = snapped;

    final state = _states.resolve(
      tracking: tracking,
      mode: input.mode,
      actionable: actionable,
      hasPosition: _model.position != SieSpatialPoint2D.zero || raw != null,
      paused: paused,
    );
    _model.state = state;

    final vis = _visibility.update(
      state: state,
      config: _config.motion,
      now: input.timestamp,
      movedThisFrame: moved,
      lastMoveAt: _model.lastMoveAt,
    );
    _model.visibility = vis.mode;
    _model.opacity = vis.opacity;

    final anim = _animator.advance(
      now: input.timestamp,
      state: state,
      reducedMotion: _config.motion.reducedMotion,
    );
    _model.animationPhase = anim;

    final speed = math.sqrt(
      _model.velocity.x * _model.velocity.x +
          _model.velocity.y * _model.velocity.y,
    );
    final dir = speed > 1e-6
        ? SieSpatialPoint2D(
            _model.velocity.x / speed,
            _model.velocity.y / speed,
          )
        : SieSpatialPoint2D.zero;

    final snap = SieCursorSnapshot(
      timestamp: input.timestamp,
      frameSequence: input.frameSequence,
      position: _model.position,
      rawPosition: _model.rawPosition,
      velocity: _model.velocity,
      direction: dir,
      acceleration: speed,
      state: state,
      visibility: vis.mode,
      opacity: vis.opacity,
      theme: _config.theme,
      interactionMode: input.mode,
      trackingState: tracking,
      hoverTargetId: hoverId,
      snapTargetId: snapId,
      snapped: snapped,
      predictionOffset: predictionOffset,
      smoothingAlpha: _filter.lastAlpha,
      animationPhase: anim,
      metadata: {
        'clamped': clamped,
        'armed': armed,
        'snapAllowed': _config.snapAllowed,
      },
    );

    _prevTimestamp = input.timestamp;
    return SieCursorEvalResult(
      snapshot: snap,
      clamped: clamped,
      snapped: snapped,
    );
  }

  double _deltaMs(DateTime now) {
    final prev = _prevTimestamp;
    if (prev == null) return 16;
    final ms = now.difference(prev).inMilliseconds.toDouble();
    if (ms <= 0) return 16;
    return ms.clamp(1, 100);
  }

  static SieTrackingReliabilityState _trackingFrom(
    List<SieIntentEvent> actionable,
    SieIntentFrameSnapshot input,
  ) {
    if (actionable.isNotEmpty) return actionable.first.trackingState;
    // Fall back: if mode blocked, treat as lost.
    if (input.mode == SieInteractionMode.blocked) {
      return SieTrackingReliabilityState.lostTracking;
    }
    return SieTrackingReliabilityState.stable;
  }

  static bool _isFinite(SieSpatialPoint2D p) =>
      p.x.isFinite && p.y.isFinite;
}
