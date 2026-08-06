import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_sources.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_hysteresis_gate.dart';

/// Result of a state-machine step.
final class SieTrackingStateStep {
  /// Creates step result.
  const SieTrackingStateStep({
    required this.state,
    required this.recovery,
    required this.gestureReady,
    required this.enteredLost,
    required this.completedRecovery,
    required this.enteredTracking,
  });

  /// New state.
  final SieTrackingReliabilityState state;

  /// Recovery status.
  final SieRecoveryStatus recovery;

  /// Gesture-ready latched flag.
  final bool gestureReady;

  /// Transitioned into LostTracking this frame.
  final bool enteredLost;

  /// Completed Recovering → Tracking this frame.
  final bool completedRecovery;

  /// Acquired tracking from idle/lost this frame.
  final bool enteredTracking;
}

/// IDS tracking reliability state machine with hysteresis (ADR-015/016).
final class SieTrackingStateMachine {
  /// Creates the machine.
  SieTrackingStateMachine({
    required SieConfidenceThresholds thresholds,
  }) : _thresholds = thresholds {
    _rebuildGates(trackActive: false, stableActive: false);
  }

  SieConfidenceThresholds _thresholds;
  late SieHysteresisGate _trackGate;
  late SieHysteresisGate _stableGate;
  late SieHysteresisGate _gestureReadyGate;

  SieTrackingReliabilityState _state = SieTrackingReliabilityState.idle;
  DateTime? _recoveryStartedAt;
  DateTime? _absenceStartedAt;
  bool _enabled = true;

  /// Current state.
  SieTrackingReliabilityState get state => _state;

  /// Replace thresholds (policy change).
  void applyThresholds(SieConfidenceThresholds value) {
    final trackActive = _trackGate.active;
    final stableActive = _stableGate.active;
    final gestureActive = _gestureReadyGate.active;
    _thresholds = value;
    _rebuildGates(
      trackActive: trackActive,
      stableActive: stableActive,
      gestureActive: gestureActive,
    );
  }

  void _rebuildGates({
    required bool trackActive,
    required bool stableActive,
    bool gestureActive = false,
  }) {
    final t = _thresholds;
    _trackGate = SieHysteresisGate(
      enterThreshold: t.trackEnter,
      exitThreshold: t.trackExit,
      enterFrames: t.enterFrames,
      exitFrames: t.exitFrames,
      initial: trackActive,
    );
    _stableGate = SieHysteresisGate(
      enterThreshold: t.stableEnter,
      exitThreshold: t.stableExit,
      enterFrames: t.enterFrames,
      exitFrames: t.exitFrames,
      initial: stableActive,
    );
    _gestureReadyGate = SieHysteresisGate(
      enterThreshold: t.gestureReadyEnter,
      exitThreshold: t.gestureReadyExit,
      enterFrames: t.enterFrames,
      exitFrames: t.exitFrames,
      initial: gestureActive,
    );
  }

  /// Enable / disable (Disabled state).
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _state = SieTrackingReliabilityState.disabled;
      _recoveryStartedAt = null;
      _absenceStartedAt = null;
      _trackGate.reset();
      _stableGate.reset();
      _gestureReadyGate.reset();
    } else if (_state == SieTrackingReliabilityState.disabled) {
      _state = SieTrackingReliabilityState.idle;
    }
  }

  /// Force error.
  void setError() {
    _state = SieTrackingReliabilityState.error;
    _gestureReadyGate.reset();
  }

  /// Clear error → idle.
  void clearError() {
    if (_state == SieTrackingReliabilityState.error) {
      _state = _enabled
          ? SieTrackingReliabilityState.idle
          : SieTrackingReliabilityState.disabled;
    }
  }

  /// Reset to idle.
  void reset() {
    _state = _enabled
        ? SieTrackingReliabilityState.idle
        : SieTrackingReliabilityState.disabled;
    _recoveryStartedAt = null;
    _absenceStartedAt = null;
    _trackGate.reset();
    _stableGate.reset();
    _gestureReadyGate.reset();
  }

  /// Step the machine.
  SieTrackingStateStep step({
    required bool hasHand,
    required double confidence,
    required double stability,
    required DateTime now,
  }) {
    if (!_enabled) {
      return const SieTrackingStateStep(
        state: SieTrackingReliabilityState.disabled,
        recovery: SieRecoveryStatus.none,
        gestureReady: false,
        enteredLost: false,
        completedRecovery: false,
        enteredTracking: false,
      );
    }
    if (_state == SieTrackingReliabilityState.error) {
      return const SieTrackingStateStep(
        state: SieTrackingReliabilityState.error,
        recovery: SieRecoveryStatus.none,
        gestureReady: false,
        enteredLost: false,
        completedRecovery: false,
        enteredTracking: false,
      );
    }

    final prev = _state;
    var enteredLost = false;
    var completedRecovery = false;
    var enteredTracking = false;

    final trackingLatched = _trackGate.update(hasHand ? confidence : 0);
    final stableLatched =
        _stableGate.update(hasHand ? _min(confidence, stability) : 0);
    final gestureReadyRaw = _gestureReadyGate.update(hasHand ? confidence : 0);

    if (!hasHand) {
      _absenceStartedAt ??= now;
      final absentMs = now.difference(_absenceStartedAt!).inMilliseconds;
      final wasActive = prev == SieTrackingReliabilityState.tracking ||
          prev == SieTrackingReliabilityState.stable ||
          prev == SieTrackingReliabilityState.degraded ||
          prev == SieTrackingReliabilityState.recovering;

      if (wasActive && absentMs >= _thresholds.lostMs) {
        if (prev != SieTrackingReliabilityState.lostTracking) {
          enteredLost = true;
        }
        _state = SieTrackingReliabilityState.lostTracking;
        _recoveryStartedAt = null;
        _trackGate.reset();
        _stableGate.reset();
        _gestureReadyGate.reset();
      } else if (wasActive) {
        // Grace: hold prior state briefly (noise suppression).
        _state = prev;
      } else {
        _state = prev == SieTrackingReliabilityState.lostTracking
            ? SieTrackingReliabilityState.lostTracking
            : SieTrackingReliabilityState.idle;
      }
    } else {
      // Hand present.
      _absenceStartedAt = null;

      // ADR-016: reacquire from LostTracking always enters Recovering first.
      if (prev == SieTrackingReliabilityState.lostTracking) {
        _state = SieTrackingReliabilityState.recovering;
        _recoveryStartedAt ??= now;
      } else if (prev == SieTrackingReliabilityState.recovering) {
        final started = _recoveryStartedAt ?? now;
        final elapsed = now.difference(started).inMilliseconds;
        if (trackingLatched &&
            elapsed >= _thresholds.recoverMs &&
            confidence >= _thresholds.recoveryEnter) {
          _state = stableLatched &&
                  stability >= _thresholds.stabilityEnter
              ? SieTrackingReliabilityState.stable
              : SieTrackingReliabilityState.tracking;
          _recoveryStartedAt = null;
          completedRecovery = true;
          enteredTracking = true;
        } else {
          _state = SieTrackingReliabilityState.recovering;
        }
      } else if (!trackingLatched) {
        // Hand visible but confidence not latched.
        if (prev == SieTrackingReliabilityState.tracking ||
            prev == SieTrackingReliabilityState.stable) {
          _state = SieTrackingReliabilityState.degraded;
        } else if (prev == SieTrackingReliabilityState.degraded) {
          final started = _absenceStartedAt ?? now;
          final absentMs = now.difference(started).inMilliseconds;
          if (confidence < _thresholds.trackExit &&
              absentMs >= _thresholds.lostMs) {
            enteredLost = true;
            _state = SieTrackingReliabilityState.lostTracking;
            _trackGate.reset();
            _stableGate.reset();
            _gestureReadyGate.reset();
          } else {
            _state = SieTrackingReliabilityState.degraded;
          }
        } else {
          _state = SieTrackingReliabilityState.idle;
        }
      } else if (prev == SieTrackingReliabilityState.idle ||
          prev == SieTrackingReliabilityState.disabled) {
        _state = SieTrackingReliabilityState.tracking;
        enteredTracking = true;
        _recoveryStartedAt = null;
      } else if (confidence < _thresholds.degradedEnter ||
          stability < _thresholds.stabilityExit * 0.9) {
        _state = SieTrackingReliabilityState.degraded;
      } else if (stableLatched &&
          confidence >= _thresholds.stableEnter &&
          stability >= _thresholds.stabilityEnter) {
        _state = SieTrackingReliabilityState.stable;
      } else {
        _state = SieTrackingReliabilityState.tracking;
      }
    }

    final recovery = _buildRecovery(now);
    final gestureReady = gestureReadyRaw &&
        !recovery.commitsSuppressed &&
        _state != SieTrackingReliabilityState.lostTracking &&
        _state != SieTrackingReliabilityState.idle &&
        _state != SieTrackingReliabilityState.disabled;

    return SieTrackingStateStep(
      state: _state,
      recovery: recovery,
      gestureReady: gestureReady,
      enteredLost: enteredLost,
      completedRecovery: completedRecovery,
      enteredTracking: enteredTracking,
    );
  }

  SieRecoveryStatus _buildRecovery(DateTime now) {
    if (_state != SieTrackingReliabilityState.recovering) {
      return SieRecoveryStatus.none;
    }
    final started = _recoveryStartedAt ?? now;
    final elapsed = now.difference(started).inMilliseconds.toDouble();
    final remaining =
        (_thresholds.recoverMs - elapsed).clamp(0, _thresholds.recoverMs);
    return SieRecoveryStatus(
      inRecovery: true,
      elapsedMs: elapsed,
      remainingMs: remaining.toDouble(),
      commitsSuppressed: true,
    );
  }

  static double _min(double a, double b) => a < b ? a : b;
}
