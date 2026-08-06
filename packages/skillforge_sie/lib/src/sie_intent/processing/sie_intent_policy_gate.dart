import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// Result of gating a candidate.
final class SieIntentGateResult {
  /// Allowed.
  const SieIntentGateResult.allow()
      : allowed = true,
        reason = null;

  /// Suppressed.
  const SieIntentGateResult.deny(this.reason) : allowed = false;

  /// Whether allowed.
  final bool allowed;

  /// Suppression reason.
  final SieIntentSuppressionReason? reason;
}

/// Enforces IDS security + route + intent policies.
final class SieIntentPolicyGate {
  /// Creates gate.
  const SieIntentPolicyGate();

  /// Evaluate whether [candidate] may be emitted under [context].
  SieIntentGateResult evaluate({
    required SieIntentCandidate candidate,
    required SieIntentContext context,
  }) {
    final kind = candidate.kind;

    // Future intents never activate in v1.
    if (kind == SieIntentKind.zoomDelta ||
        kind == SieIntentKind.rotateDelta ||
        kind == SieIntentKind.navigateRelative) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.futureNotActivated,
      );
    }

    if (!context.platformAllowsSie || !context.sieEnabled) {
      if (kind != SieIntentKind.pauseSie) {
        return const SieIntentGateResult.deny(
          SieIntentSuppressionReason.sessionPaused,
        );
      }
    }

    if (context.paused) {
      if (kind != SieIntentKind.resumeSie && kind != SieIntentKind.pauseSie) {
        return const SieIntentGateResult.deny(
          SieIntentSuppressionReason.sessionPaused,
        );
      }
    }

    // Tracking gates.
    final tracking = context.trackingState;
    if (tracking == SieTrackingReliabilityState.disabled ||
        tracking == SieTrackingReliabilityState.error) {
      if (kind != SieIntentKind.pauseSie) {
        return const SieIntentGateResult.deny(
          SieIntentSuppressionReason.trackingState,
        );
      }
    }
    if (tracking == SieTrackingReliabilityState.lostTracking) {
      // Only cancel / pause allowed on loss.
      if (kind != SieIntentKind.cancel && kind != SieIntentKind.pauseSie) {
        return const SieIntentGateResult.deny(
          SieIntentSuppressionReason.trackingState,
        );
      }
    }
    if (tracking == SieTrackingReliabilityState.recovering ||
        context.commitsSuppressed) {
      if (_isCommitFamily(kind)) {
        return const SieIntentGateResult.deny(
          SieIntentSuppressionReason.trackingState,
        );
      }
    }

    // Security L3/L4 — no gesture commit / activate.
    if (!_securityAllows(kind, context.securityLevel)) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.securityPolicy,
      );
    }

    // Route capability.
    if (!context.route.allows(kind)) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.routePolicy,
      );
    }
    if (!context.route.allowDrag && _isDragFamily(kind)) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.routePolicy,
      );
    }
    if (!context.route.allowScroll && kind == SieIntentKind.scrollDelta) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.routePolicy,
      );
    }

    // Intent policy.
    if (!context.policy.allows(kind)) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.intentPolicy,
      );
    }

    // Hover requirement for select.
    if (_isSelectFamily(kind) &&
        context.route.requireHoverForSelect &&
        (context.hoveredTargetId == null ||
            context.hoveredTargetId!.isEmpty)) {
      return const SieIntentGateResult.deny(
        SieIntentSuppressionReason.hoverRequired,
      );
    }

    return const SieIntentGateResult.allow();
  }

  static bool _isCommitFamily(SieIntentKind kind) =>
      kind == SieIntentKind.select ||
      kind == SieIntentKind.selectHold ||
      kind == SieIntentKind.beginDrag ||
      kind == SieIntentKind.updateDrag ||
      kind == SieIntentKind.endDrag ||
      kind == SieIntentKind.dwellSelect;

  static bool _isSelectFamily(SieIntentKind kind) =>
      kind == SieIntentKind.select ||
      kind == SieIntentKind.selectHold ||
      kind == SieIntentKind.selectRelease ||
      kind == SieIntentKind.dwellSelect;

  static bool _isDragFamily(SieIntentKind kind) =>
      kind == SieIntentKind.beginDrag ||
      kind == SieIntentKind.updateDrag ||
      kind == SieIntentKind.endDrag;

  /// IDS §9 security matrix.
  static bool _securityAllows(SieIntentKind kind, SieSecurityLevel level) {
    switch (level) {
      case SieSecurityLevel.l0Public:
      case SieSecurityLevel.l1Standard:
        return true;
      case SieSecurityLevel.l2Elevated:
        // Select allowed (with confirms — confirm is host concern).
        return true;
      case SieSecurityLevel.l3Sensitive:
        // No gesture commit / drag activate; locomotion + cancel OK.
        return kind == SieIntentKind.moveCursor ||
            kind == SieIntentKind.hoverEnter ||
            kind == SieIntentKind.hoverExit ||
            kind == SieIntentKind.cancel ||
            kind == SieIntentKind.scrollDelta ||
            kind == SieIntentKind.pauseSie ||
            kind == SieIntentKind.resumeSie;
      case SieSecurityLevel.l4Irreversible:
        // SIE disabled for activate/confirm — locomotion may remain for browse.
        return kind == SieIntentKind.moveCursor ||
            kind == SieIntentKind.hoverEnter ||
            kind == SieIntentKind.hoverExit ||
            kind == SieIntentKind.cancel ||
            kind == SieIntentKind.pauseSie ||
            kind == SieIntentKind.resumeSie;
    }
  }
}
