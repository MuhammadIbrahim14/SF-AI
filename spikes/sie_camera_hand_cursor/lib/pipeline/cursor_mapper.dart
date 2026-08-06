import 'dart:math' as math;

import 'package:sie_camera_hand_cursor/models/spike_models.dart';

/// Maps normalized hand landmarks → smoothed screen cursor (spike-only).
class CursorMapper {
  CursorMapper({
    this.smoothing = 0.35,
    this.mirrorX = true,
  });

  /// EMA alpha (higher = more responsive, more jitter).
  double smoothing;
  bool mirrorX;

  double? _sx;
  double? _sy;
  DateTime? _lostAt;
  TrackingState _state = TrackingState.searching;
  int lossCount = 0;
  double lastRecoveryMs = 0;

  TrackingState get state => _state;

  CursorState update({
    required SpikeHandSample sample,
    required double screenW,
    required double screenH,
  }) {
    final tip = sample.pointingLandmark;
    if (!sample.detected || tip == null) {
      _lostAt ??= DateTime.now();
      final lostFor = DateTime.now().difference(_lostAt!).inMilliseconds;
      if (_state == TrackingState.tracking || _state == TrackingState.recovering) {
        if (lostFor > 120) {
          if (_state == TrackingState.tracking) lossCount += 1;
          _state = lostFor > 500 ? TrackingState.lost : TrackingState.recovering;
        }
      } else if (_state == TrackingState.searching) {
        // stay searching
      } else {
        _state = TrackingState.lost;
      }

      return CursorState(
        x: _sx ?? screenW * 0.5,
        y: _sy ?? screenH * 0.5,
        visible: _state == TrackingState.recovering && _sx != null,
        rawX: _sx ?? screenW * 0.5,
        rawY: _sy ?? screenH * 0.5,
      );
    }

    // Recovered
    if (_lostAt != null) {
      lastRecoveryMs = DateTime.now().difference(_lostAt!).inMilliseconds.toDouble();
      _lostAt = null;
    }
    _state = TrackingState.tracking;

    var nx = tip.x.clamp(0.0, 1.0);
    var ny = tip.y.clamp(0.0, 1.0);
    if (mirrorX) nx = 1.0 - nx;

    // Soft edge inset so cursor does not stick hard to bezels.
    const inset = 0.02;
    nx = _mapRange(nx, inset, 1 - inset, 0, 1);
    ny = _mapRange(ny, inset, 1 - inset, 0, 1);

    final rawX = nx * screenW;
    final rawY = ny * screenH;

    if (_sx == null || _sy == null) {
      _sx = rawX;
      _sy = rawY;
    } else {
      _sx = _sx! + (rawX - _sx!) * smoothing;
      _sy = _sy! + (rawY - _sy!) * smoothing;
    }

    return CursorState(
      x: _sx!,
      y: _sy!,
      visible: true,
      rawX: rawX,
      rawY: rawY,
    );
  }

  void reset() {
    _sx = null;
    _sy = null;
    _lostAt = null;
    _state = TrackingState.searching;
    lossCount = 0;
    lastRecoveryMs = 0;
  }

  static double _mapRange(
    double v,
    double inMin,
    double inMax,
    double outMin,
    double outMax,
  ) {
    final t = ((v - inMin) / (inMax - inMin)).clamp(0.0, 1.0);
    return outMin + t * (outMax - outMin);
  }

  /// Rough jitter estimate (px) between consecutive smoothed positions.
  static double jitterPx(CursorState a, CursorState b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
