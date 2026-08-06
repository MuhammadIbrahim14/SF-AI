import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_snapshot.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Result of gating + ordering a dispatch batch.
final class SieOrchestrationGateResult {
  /// Creates result.
  const SieOrchestrationGateResult({
    required this.decision,
    required this.events,
    required this.mode,
    required this.sieDispatchEnabled,
  });

  /// Decision.
  final SieDispatchDecision decision;

  /// Ordered events to dispatch (may be empty).
  final List<SiePointerEvent> events;

  /// Mode.
  final SieOrchestrationMode mode;

  /// Whether SIE path was enabled.
  final bool sieDispatchEnabled;
}

/// Gates and orders interaction delivery (no gesture / CV / cursor logic).
final class SieOrchestrationCoordinator {
  /// Creates coordinator.
  const SieOrchestrationCoordinator();

  /// Evaluate one frame.
  SieOrchestrationGateResult evaluate({
    required SieOrchestrationContext context,
    required SieArbitrationSnapshot arbitration,
    required List<SiePointerEvent> siePointerEvents,
  }) {
    final mode = _mode(context, arbitration);

    if (!context.interactionEnabled) {
      return SieOrchestrationGateResult(
        decision: SieDispatchDecision.blockedDisabled,
        events: const [],
        mode: SieOrchestrationMode.disabled,
        sieDispatchEnabled: false,
      );
    }

    if (!context.mayDispatch) {
      final decision = !context.focus.windowFocused
          ? SieDispatchDecision.blockedFocus
          : SieDispatchDecision.blockedLifecycle;
      return SieOrchestrationGateResult(
        decision: decision,
        events: const [],
        mode: mode,
        sieDispatchEnabled: false,
      );
    }

    // Traditional owner — orchestrator does not synthesize OS events;
    // SIE batch must not forward.
    if (arbitration.owner.isTraditional ||
        arbitration.owner == SieInputSource.none) {
      return SieOrchestrationGateResult(
        decision: siePointerEvents.isEmpty
            ? SieDispatchDecision.skippedEmpty
            : SieDispatchDecision.blockedArbitration,
        events: const [],
        mode: mode,
        sieDispatchEnabled: false,
      );
    }

    // SIE owner path.
    if (arbitration.owner != SieInputSource.sie ||
        !arbitration.forwardsSiePointers) {
      return SieOrchestrationGateResult(
        decision: SieDispatchDecision.blockedArbitration,
        events: const [],
        mode: mode,
        sieDispatchEnabled: false,
      );
    }

    if (!context.sieContextAllowed) {
      final decision = !context.availability.sieOperational
          ? SieDispatchDecision.blockedFeature
          : (context.modal != SieModalKind.none
              ? SieDispatchDecision.blockedModal
              : SieDispatchDecision.blockedRoute);
      return SieOrchestrationGateResult(
        decision: decision,
        events: const [],
        mode: mode,
        sieDispatchEnabled: false,
      );
    }

    if (siePointerEvents.isEmpty) {
      return SieOrchestrationGateResult(
        decision: SieDispatchDecision.skippedEmpty,
        events: const [],
        mode: mode,
        sieDispatchEnabled: true,
      );
    }

    // Preserve order — never reorder.
    final ordered = List<SiePointerEvent>.unmodifiable(siePointerEvents);
    return SieOrchestrationGateResult(
      decision: SieDispatchDecision.dispatched,
      events: ordered,
      mode: mode,
      sieDispatchEnabled: true,
    );
  }

  static SieOrchestrationMode _mode(
    SieOrchestrationContext context,
    SieArbitrationSnapshot arbitration,
  ) {
    if (!context.interactionEnabled) return SieOrchestrationMode.disabled;
    if (context.modal != SieModalKind.none) return SieOrchestrationMode.modal;
    if (context.lifecycle == SieAppLifecycleState.paused ||
        context.lifecycle == SieAppLifecycleState.background) {
      return SieOrchestrationMode.disabled;
    }
    if (!context.availability.sieOperational) {
      return SieOrchestrationMode.traditionalOnly;
    }
    if (arbitration.owner == SieInputSource.sie &&
        arbitration.forwardsSiePointers) {
      return SieOrchestrationMode.sieActive;
    }
    if (arbitration.owner.isTraditional) {
      return SieOrchestrationMode.traditionalOnly;
    }
    if (arbitration.reason == SieOwnershipReason.lostTracking) {
      return SieOrchestrationMode.recovering;
    }
    return SieOrchestrationMode.coordinating;
  }
}
