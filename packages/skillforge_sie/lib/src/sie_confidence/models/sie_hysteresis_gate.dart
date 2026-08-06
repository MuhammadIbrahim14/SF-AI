/// Binary hysteresis gate with temporal persistence (ADR-015).
final class SieHysteresisGate {
  /// Creates a gate.
  SieHysteresisGate({
    required this.enterThreshold,
    required this.exitThreshold,
    required this.enterFrames,
    required this.exitFrames,
    bool initial = false,
  })  : assert(enterThreshold > exitThreshold, 'enter must exceed exit'),
        active = initial;

  /// Enter threshold.
  final double enterThreshold;

  /// Exit threshold.
  final double exitThreshold;

  /// Frames required above enter.
  final int enterFrames;

  /// Frames required below exit.
  final int exitFrames;

  /// Current latched state.
  bool active;

  int _enterStreak = 0;
  int _exitStreak = 0;

  /// Whether the gate is latched on.
  bool get isActive => active;

  /// Update with a new sample; returns latched state.
  bool update(double value) {
    if (active) {
      if (value < exitThreshold) {
        _exitStreak++;
        _enterStreak = 0;
        if (_exitStreak >= exitFrames) {
          active = false;
          _exitStreak = 0;
        }
      } else {
        _exitStreak = 0;
      }
    } else {
      if (value >= enterThreshold) {
        _enterStreak++;
        _exitStreak = 0;
        if (_enterStreak >= enterFrames) {
          active = true;
          _enterStreak = 0;
        }
      } else {
        _enterStreak = 0;
      }
    }
    return active;
  }

  /// Force state (e.g. on tracking loss).
  void reset({bool to = false}) {
    active = to;
    _enterStreak = 0;
    _exitStreak = 0;
  }
}
