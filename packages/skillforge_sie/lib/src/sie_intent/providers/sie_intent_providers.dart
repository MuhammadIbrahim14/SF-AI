import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_intent/engine/sie_intent_engine.dart';
import 'package:skillforge_sie/src/sie_intent/logging/sie_intent_logger.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_engine_status.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';
import 'package:skillforge_sie/src/sie_intent/ports/intent_engine_port.dart';

/// Active intent policy (low frequency).
final sieIntentPolicyProvider =
    NotifierProvider<SieIntentPolicyNotifier, SieIntentPolicy>(
  SieIntentPolicyNotifier.new,
);

/// Holds [SieIntentPolicy].
final class SieIntentPolicyNotifier extends Notifier<SieIntentPolicy> {
  @override
  SieIntentPolicy build() => SieIntentPolicy.standard;

  /// Replaces policy and pushes into the engine.
  void update(SieIntentPolicy policy) {
    state = policy;
    unawaited(ref.read(sieIntentEngineProvider).setPolicy(policy));
  }
}

/// Interaction context (route / security / hover) — low frequency.
final sieIntentContextProvider =
    NotifierProvider<SieIntentContextNotifier, SieIntentContext>(
  SieIntentContextNotifier.new,
);

/// Holds [SieIntentContext].
final class SieIntentContextNotifier extends Notifier<SieIntentContext> {
  @override
  SieIntentContext build() => SieIntentContext.dashboard();

  /// Replaces context and pushes into the engine.
  void update(SieIntentContext context) {
    state = context;
    unawaited(ref.read(sieIntentEngineProvider).updateContext(context));
  }
}

/// Intent engine instance (events/snapshots are not published to Riverpod).
final sieIntentEngineProvider = Provider<IntentEnginePort>((ref) {
  final engine = SieIntentEngine(
    context: ref.read(sieIntentContextProvider),
    policy: ref.read(sieIntentPolicyProvider),
    logger: const DeveloperSieIntentLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieIntentEngineStatusProvider =
    StreamProvider<SieIntentEngineStatus>((ref) {
  return ref.watch(sieIntentEngineProvider).status;
});

/// Availability / mode / policy / health for host UI (ADR-008).
final sieIntentAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieInteractionMode mode,
  SieIntentPolicyId policyId,
  SieSecurityLevel securityLevel,
  SieRouteCapabilityKind routeKind,
  SieIntentEngineHealth health,
  SieIntentEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieIntentEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    mode: status?.mode ?? SieInteractionMode.idle,
    policyId: status?.policyId ?? ref.watch(sieIntentPolicyProvider).id,
    securityLevel:
        status?.securityLevel ?? SieSecurityLevel.l1Standard,
    routeKind: status?.routeKind ?? SieRouteCapabilityKind.dashboard,
    health: status?.health ?? SieIntentEngineHealth.idle,
    status: status,
  );
});
