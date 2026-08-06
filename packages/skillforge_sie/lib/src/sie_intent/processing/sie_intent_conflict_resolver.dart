import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/processing/sie_intent_policy_gate.dart';

/// Conflict resolution outcome.
final class SieIntentConflictResult {
  /// Creates result.
  const SieIntentConflictResult({
    required this.accepted,
    required this.suppressed,
    required this.primaryKind,
    required this.conflicts,
  });

  /// Candidates allowed through.
  final List<SieIntentCandidate> accepted;

  /// Candidates suppressed for conflict (with reason applied later).
  final List<SieIntentCandidate> suppressed;

  /// Primary actionable kind.
  final SieIntentKind? primaryKind;

  /// Conflict count.
  final int conflicts;
}

/// Resolves competing intents.
///
/// Priority (lower number wins):
/// 1 Error · 2 Disabled · 3 LostTracking · 4 Recovering ·
/// 5 Cancel · 6 Select · 7 Drag · 8 Scroll · 9 Hover · 10 MoveCursor
final class SieIntentConflictResolver {
  /// Creates resolver.
  const SieIntentConflictResolver();

  /// Resolve gated candidates (already policy-allowed) plus optional suppress log.
  SieIntentConflictResult resolve(List<SieIntentCandidate> allowed) {
    if (allowed.isEmpty) {
      return const SieIntentConflictResult(
        accepted: [],
        suppressed: [],
        primaryKind: null,
        conflicts: 0,
      );
    }

    final sorted = List<SieIntentCandidate>.of(allowed)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final winner = sorted.first;
    final accepted = <SieIntentCandidate>[];
    final suppressed = <SieIntentCandidate>[];
    var conflicts = 0;

    for (final c in sorted) {
      if (_compatibleWithPrimary(winner, c)) {
        accepted.add(c);
      } else {
        suppressed.add(c);
        conflicts++;
      }
    }

    return SieIntentConflictResult(
      accepted: accepted,
      suppressed: suppressed,
      primaryKind: winner.kind,
      conflicts: conflicts,
    );
  }

  /// Whether [c] may coexist with [winner].
  static bool _compatibleWithPrimary(
    SieIntentCandidate winner,
    SieIntentCandidate c,
  ) {
    if (identical(winner, c) ||
        (winner.kind == c.kind && winner.phase == c.phase)) {
      return true;
    }
    // Cancel preempts everything else.
    if (winner.kind == SieIntentKind.cancel) {
      return c.kind == SieIntentKind.cancel;
    }
    // Same family always OK.
    if (_family(winner.kind) == _family(c.kind)) {
      return true;
    }
    // Locomotion + hover may accompany select/drag/scroll.
    if (c.kind == SieIntentKind.moveCursor ||
        c.kind == SieIntentKind.hoverEnter ||
        c.kind == SieIntentKind.hoverExit) {
      return winner.kind != SieIntentKind.cancel;
    }
    // Pause/resume are session-level and exclusive when primary.
    if (winner.kind == SieIntentKind.pauseSie ||
        winner.kind == SieIntentKind.resumeSie) {
      return c.kind == winner.kind;
    }
    // Same priority class (e.g. select + selectHold) already covered by family.
    return c.priority == winner.priority && _family(c.kind) == _family(winner.kind);
  }

  static int _family(SieIntentKind kind) {
    return switch (kind) {
      SieIntentKind.cancel => 5,
      SieIntentKind.select ||
      SieIntentKind.selectHold ||
      SieIntentKind.selectRelease ||
      SieIntentKind.dwellSelect =>
        6,
      SieIntentKind.beginDrag ||
      SieIntentKind.updateDrag ||
      SieIntentKind.endDrag =>
        7,
      SieIntentKind.scrollDelta => 8,
      SieIntentKind.hoverEnter || SieIntentKind.hoverExit => 9,
      SieIntentKind.moveCursor => 10,
      SieIntentKind.pauseSie || SieIntentKind.resumeSie => 4,
      SieIntentKind.zoomDelta ||
      SieIntentKind.rotateDelta ||
      SieIntentKind.navigateRelative =>
        99,
    };
  }
}

/// Applies gate then conflict resolution.
final class SieIntentEvaluator {
  /// Creates evaluator.
  SieIntentEvaluator({
    SieIntentPolicyGate gate = const SieIntentPolicyGate(),
    SieIntentConflictResolver conflict = const SieIntentConflictResolver(),
  })  : _gate = gate,
        _conflict = conflict;

  final SieIntentPolicyGate _gate;
  final SieIntentConflictResolver _conflict;

  /// Evaluate candidates under [context].
  ({
    List<SieIntentCandidate> accepted,
    List<(SieIntentCandidate, SieIntentSuppressionReason)> denied,
    SieIntentKind? primaryKind,
    int conflicts,
    int securityBlocks,
    int routeBlocks,
  }) evaluate({
    required List<SieIntentCandidate> candidates,
    required SieIntentContext context,
  }) {
    final allowed = <SieIntentCandidate>[];
    final denied = <(SieIntentCandidate, SieIntentSuppressionReason)>[];
    var securityBlocks = 0;
    var routeBlocks = 0;

    for (final c in candidates) {
      final gate = _gate.evaluate(candidate: c, context: context);
      if (gate.allowed) {
        allowed.add(c);
      } else {
        denied.add((c, gate.reason!));
        if (gate.reason == SieIntentSuppressionReason.securityPolicy) {
          securityBlocks++;
        }
        if (gate.reason == SieIntentSuppressionReason.routePolicy) {
          routeBlocks++;
        }
      }
    }

    final resolved = _conflict.resolve(allowed);
    for (final c in resolved.suppressed) {
      denied.add((c, SieIntentSuppressionReason.conflict));
    }

    return (
      accepted: resolved.accepted,
      denied: denied,
      primaryKind: resolved.primaryKind,
      conflicts: resolved.conflicts,
      securityBlocks: securityBlocks,
      routeBlocks: routeBlocks,
    );
  }
}
