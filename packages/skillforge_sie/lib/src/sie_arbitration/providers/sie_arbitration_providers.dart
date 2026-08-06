import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_arbitration/engine/sie_input_arbitration_engine.dart';
import 'package:skillforge_sie/src/sie_arbitration/logging/sie_arbitration_logger.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_engine_status.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_policy.dart';
import 'package:skillforge_sie/src/sie_arbitration/ports/input_arbitration_engine_port.dart';

/// Active arbitration policy (low frequency).
final sieArbitrationPolicyProvider =
    NotifierProvider<SieArbitrationPolicyNotifier, SieArbitrationPolicy>(
  SieArbitrationPolicyNotifier.new,
);

/// Holds [SieArbitrationPolicy].
final class SieArbitrationPolicyNotifier
    extends Notifier<SieArbitrationPolicy> {
  @override
  SieArbitrationPolicy build() => SieArbitrationPolicy.lastActiveWins;

  /// Replaces policy.
  void update(SieArbitrationPolicy policy) {
    state = policy;
    unawaited(ref.read(sieInputArbitrationEngineProvider).setPolicy(policy));
  }
}

/// Arbitration context (route / locks) — low frequency.
final sieArbitrationContextProvider =
    NotifierProvider<SieArbitrationContextNotifier, SieArbitrationContext>(
  SieArbitrationContextNotifier.new,
);

/// Holds [SieArbitrationContext].
final class SieArbitrationContextNotifier
    extends Notifier<SieArbitrationContext> {
  @override
  SieArbitrationContext build() => SieArbitrationContext.dashboard();

  /// Replaces context.
  void update(SieArbitrationContext context) {
    state = context;
    unawaited(
      ref.read(sieInputArbitrationEngineProvider).updateContext(context),
    );
  }
}

/// Arbitration engine (snapshots not published to Riverpod).
final sieInputArbitrationEngineProvider =
    Provider<InputArbitrationEnginePort>((ref) {
  final engine = SieInputArbitrationEngine(
    policy: ref.read(sieArbitrationPolicyProvider),
    context: ref.read(sieArbitrationContextProvider),
    logger: const DeveloperSieArbitrationLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieArbitrationEngineStatusProvider =
    StreamProvider<SieArbitrationEngineStatus>((ref) {
  return ref.watch(sieInputArbitrationEngineProvider).status;
});

/// Owner / policy / availability / health for host UI (ADR-008).
final sieArbitrationAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieInputSource owner,
  SieArbitrationPolicyId policyId,
  bool forwardsSiePointers,
  SieArbitrationEngineHealth health,
  SieArbitrationEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieArbitrationEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  final engine = ref.watch(sieInputArbitrationEngineProvider);
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    owner: status?.owner ?? SieInputSource.none,
    policyId: status?.policyId ?? ref.watch(sieArbitrationPolicyProvider).id,
    forwardsSiePointers: engine.forwardsSiePointers,
    health: status?.health ?? SieArbitrationEngineHealth.idle,
    status: status,
  );
});
