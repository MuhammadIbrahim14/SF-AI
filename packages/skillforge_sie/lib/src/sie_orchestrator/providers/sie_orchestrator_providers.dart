import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_orchestrator/engine/sie_interaction_orchestrator.dart';
import 'package:skillforge_sie/src/sie_orchestrator/logging/sie_orchestrator_logger.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_status.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_dispatch_port.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_orchestrator_port.dart';

/// Host dispatcher override point.
final sieInteractionDispatcherProvider =
    Provider<InteractionDispatchPort>((ref) {
  return const NopInteractionDispatcher();
});

/// Orchestration context (lifecycle / route / a11y) — low frequency.
final sieOrchestrationContextProvider =
    NotifierProvider<SieOrchestrationContextNotifier, SieOrchestrationContext>(
  SieOrchestrationContextNotifier.new,
);

/// Holds [SieOrchestrationContext].
final class SieOrchestrationContextNotifier
    extends Notifier<SieOrchestrationContext> {
  @override
  SieOrchestrationContext build() => const SieOrchestrationContext(
        lifecycle: SieAppLifecycleState.resumed,
        interactionEnabled: true,
      );

  /// Replaces context fields via engine APIs.
  void update(SieOrchestrationContext context) {
    state = context;
    final engine = ref.read(sieInteractionOrchestratorProvider);
    unawaited(engine.setLifecycle(context.lifecycle));
    unawaited(engine.setRoute(
      routeKind: context.routeKind,
      securityLevel: context.securityLevel,
    ));
    unawaited(engine.setFocus(context.focus));
    unawaited(engine.setModal(context.modal));
    unawaited(engine.setAccessibility(context.accessibility));
    unawaited(engine.setAvailability(context.availability));
    unawaited(engine.setInteractionEnabled(context.interactionEnabled));
  }
}

/// Orchestrator instance (snapshots not published to Riverpod).
final sieInteractionOrchestratorProvider =
    Provider<InteractionOrchestratorPort>((ref) {
  final orch = SieInteractionOrchestrator(
    context: ref.read(sieOrchestrationContextProvider),
    dispatcher: ref.read(sieInteractionDispatcherProvider),
    logger: const DeveloperSieOrchestratorLogger(),
  );
  ref.onDispose(() {
    unawaited(orch.dispose());
  });
  return orch;
});

/// Low-frequency status stream.
final sieOrchestratorStatusProvider =
    StreamProvider<SieOrchestratorStatus>((ref) {
  return ref.watch(sieInteractionOrchestratorProvider).status;
});

/// Availability / mode / lifecycle / health (ADR-008).
final sieOrchestratorAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  bool interactionEnabled,
  SieOrchestrationMode mode,
  SieAppLifecycleState lifecycle,
  SieOrchestratorHealth health,
  SieOrchestratorStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieOrchestratorStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    interactionEnabled: status?.interactionEnabled ?? false,
    mode: status?.mode ?? SieOrchestrationMode.disabled,
    lifecycle: status?.lifecycle ?? SieAppLifecycleState.cold,
    health: status?.health ?? SieOrchestratorHealth.idle,
    status: status,
  );
});
