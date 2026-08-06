import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_gesture_classifier.dart';
import 'package:skillforge_sie/src/sie_gesture/processing/sie_pinch_family_classifier.dart';

/// IDS conflict resolution result.
final class SieGestureConflictResult {
  /// Creates result.
  const SieGestureConflictResult({
    required this.primary,
    required this.events,
    required this.activity,
    required this.conflictsResolved,
    this.candidate,
    this.armingProgress = 0,
    this.dwellProgress = 0,
  });

  /// Winning hypothesis (may be non-emitting).
  final SieGestureHypothesis? primary;

  /// Events to emit this frame.
  final List<SieGestureHypothesis> events;

  /// Coarse activity.
  final SieGestureActivity activity;

  /// How many hypotheses lost.
  final int conflictsResolved;

  /// Runner-up.
  final SieGestureHypothesis? candidate;

  /// Arm progress.
  final double armingProgress;

  /// Dwell progress.
  final double dwellProgress;
}

/// Resolves simultaneous hypotheses per IDS priority.
///
/// Priority: Safety → FistCancel → Pinch → Scroll → Swipe → OpenHandPoint
final class SieGestureConflictResolver {
  /// Creates resolver.
  const SieGestureConflictResolver();

  /// Resolve.
  SieGestureConflictResult resolve({
    required List<SieGestureHypothesis> hypotheses,
    required SiePinchFamilyClassifier pinch,
    required double dwellProgress,
    required bool commitsSuppressed,
    required bool safetyBlocked,
  }) {
    if (safetyBlocked) {
      return SieGestureConflictResult(
        primary: null,
        events: const [],
        activity: SieGestureActivity.none,
        conflictsResolved: hypotheses.length,
        armingProgress: 0,
        dwellProgress: 0,
      );
    }

    final active = hypotheses.where((h) => h.phase != SieGesturePhase.idle).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (active.isEmpty) {
      return SieGestureConflictResult(
        primary: null,
        events: const [],
        activity: SieGestureActivity.none,
        conflictsResolved: 0,
        armingProgress: pinch.armingProgress,
        dwellProgress: dwellProgress,
      );
    }

    final winner = active.first;
    var conflicts = 0;
    final events = <SieGestureHypothesis>[];

    // FistCancel cancels pinch *arming only* — never steal an active press.
    // Stealing held/committed pinch dropped selectRelease and left the pointer
    // stuck down (or cancelled the tap instead of completing it).
    final fist = active.where((h) => h.kind == SieGestureKind.fistCancel).toList();
    final pinchBusy = pinch.phase == SieGesturePhase.arming ||
        pinch.phase == SieGesturePhase.committed ||
        pinch.phase == SieGesturePhase.held;
    if (fist.isNotEmpty && fist.first.emit && !pinchBusy) {
      events.add(fist.first);
      // Cancel competing pinch.
      for (final h in active) {
        if (h.kind != SieGestureKind.fistCancel) conflicts++;
      }
      return SieGestureConflictResult(
        primary: fist.first,
        events: events,
        activity: SieGestureActivity.cancelling,
        conflictsResolved: conflicts,
        candidate: active.length > 1 ? active[1] : null,
        armingProgress: 0,
        dwellProgress: 0,
      );
    }

    // While commits suppressed, drop commit/dwell/swipe emits.
    for (final h in active) {
      if (!h.emit) continue;
      if (commitsSuppressed &&
          (h.kind == SieGestureKind.pinchCommit ||
              h.kind == SieGestureKind.dwellSelect ||
              h.kind == SieGestureKind.swipeNavigation ||
              h.kind == SieGestureKind.scrollIntent)) {
        conflicts++;
        continue;
      }
      // Only primary family emits when lower priority conflicts.
      if (h.priority > winner.priority) {
        conflicts++;
        continue;
      }
      // Same priority family (pinch) — allow related emits.
      if (h.priority == winner.priority ||
          h.kind == winner.kind ||
          _sameFamily(h.kind, winner.kind)) {
        events.add(h);
      } else {
        conflicts++;
      }
    }

    // If winner doesn't emit but is active, still report as primary.
    if (events.isEmpty && winner.emit == false) {
      // keep primary for UI arming progress
    }

    return SieGestureConflictResult(
      primary: winner,
      events: events,
      activity: _activityFor(winner),
      conflictsResolved: conflicts,
      candidate: active.length > 1 ? active[1] : null,
      armingProgress: pinch.armingProgress,
      dwellProgress: dwellProgress,
    );
  }

  static bool _sameFamily(SieGestureKind a, SieGestureKind b) {
    const pinch = {
      SieGestureKind.pinchArm,
      SieGestureKind.pinchCommit,
      SieGestureKind.pinchHold,
      SieGestureKind.pinchRelease,
    };
    return pinch.contains(a) && pinch.contains(b);
  }

  static SieGestureActivity _activityFor(SieGestureHypothesis h) {
    return switch (h.kind) {
      SieGestureKind.openHandPoint => SieGestureActivity.pointing,
      SieGestureKind.pinchArm => SieGestureActivity.arming,
      SieGestureKind.pinchCommit ||
      SieGestureKind.pinchHold ||
      SieGestureKind.pinchRelease =>
        SieGestureActivity.pressed,
      SieGestureKind.scrollIntent => SieGestureActivity.scrolling,
      SieGestureKind.fistCancel => SieGestureActivity.cancelling,
      SieGestureKind.dwellSelect => SieGestureActivity.dwelling,
      SieGestureKind.swipeNavigation => SieGestureActivity.swiping,
    };
  }
}
