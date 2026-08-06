import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_arbitration/providers/sie_arbitration_providers.dart';
import 'package:skillforge_sie/src/sie_diagnostics/providers/sidf_providers.dart';
import 'package:skillforge_sie/src/sie_intent/providers/sie_intent_providers.dart';
import 'package:skillforge_sie/src/sie_integration/engine/sie_integration_framework.dart';
import 'package:skillforge_sie/src/sie_integration/logging/sie_integration_logger.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_state.dart';
import 'package:skillforge_sie/src/sie_integration/ports/sie_integration_port.dart';
import 'package:skillforge_sie/src/sie_orchestrator/providers/sie_orchestrator_providers.dart';

/// Integration Framework instance (wires orch / arbitration / intent / SIDF).
final sieIntegrationFrameworkProvider = Provider<SieIntegrationPort>((ref) {
  final framework = SieIntegrationFramework(
    orchestrator: ref.watch(sieInteractionOrchestratorProvider),
    arbitration: ref.watch(sieInputArbitrationEngineProvider),
    intent: ref.watch(sieIntentEngineProvider),
    diagnostics: ref.watch(sidfDiagnosticsFrameworkProvider),
    logger: const DeveloperSieIntegrationLogger(),
  );
  ref.onDispose(() {
    unawaited(framework.dispose());
  });
  return framework;
});

/// Low-frequency status stream.
final sieIntegrationStatusProvider =
    StreamProvider<SieIntegrationStatus>((ref) {
  return ref.watch(sieIntegrationFrameworkProvider).status;
});

/// Riverpod-safe surface only (ADR-008).
final sieIntegrationAvailabilityProvider = Provider<({
  bool available,
  SieIntegrationHealth health,
  SieIntegrationStatus? status,
  String routeId,
  SieRouteSieMode routeMode,
  bool sieEnabled,
})>((ref) {
  final asyncStatus = ref.watch(sieIntegrationStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    available: status != null &&
        status.phase != SieIntegrationPhase.unregistered &&
        status.phase != SieIntegrationPhase.disposed,
    health: status?.health ?? SieIntegrationHealth.idle,
    status: status,
    routeId: status?.routeId ?? 'landing',
    routeMode: status?.routeMode ?? SieRouteSieMode.enabled,
    sieEnabled: status?.sieEnabled ?? false,
  );
});

/// Current policy / route capability (low frequency).
final sieIntegrationPolicyProvider = Provider<({
  String routeId,
  SieRouteSieMode mode,
  bool sieEnabled,
  SieIntegrationHealth health,
})>((ref) {
  final a = ref.watch(sieIntegrationAvailabilityProvider);
  return (
    routeId: a.routeId,
    mode: a.routeMode,
    sieEnabled: a.sieEnabled,
    health: a.health,
  );
});
