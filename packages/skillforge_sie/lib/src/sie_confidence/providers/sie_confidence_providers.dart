import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_confidence/engine/sie_confidence_engine.dart';
import 'package:skillforge_sie/src/sie_confidence/logging/sie_confidence_logger.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_engine_status.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_enums.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_confidence/ports/confidence_engine_port.dart';

/// Active confidence policy id (low frequency).
final sieConfidencePolicyProvider =
    NotifierProvider<SieConfidencePolicyNotifier, SieConfidencePolicyId>(
  SieConfidencePolicyNotifier.new,
);

/// Holds [SieConfidencePolicyId].
final class SieConfidencePolicyNotifier
    extends Notifier<SieConfidencePolicyId> {
  @override
  SieConfidencePolicyId build() => SieConfidencePolicyId.standard;

  /// Replaces policy id and pushes into the engine.
  void update(SieConfidencePolicyId id) {
    state = id;
    unawaited(
      ref.read(sieConfidenceEngineProvider).setPolicy(id),
    );
  }
}

/// Confidence engine instance (snapshots are not published to Riverpod).
final sieConfidenceEngineProvider = Provider<ConfidenceEnginePort>((ref) {
  final engine = SieConfidenceEngine(
    policy: SieConfidencePolicy.fromId(
      ref.read(sieConfidencePolicyProvider),
    ),
    logger: const DeveloperSieConfidenceLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieConfidenceEngineStatusProvider =
    StreamProvider<SieConfidenceEngineStatus>((ref) {
  return ref.watch(sieConfidenceEngineProvider).status;
});

/// Availability / tracking state / policy / health for host UI.
final sieConfidenceAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieTrackingReliabilityState trackingState,
  SieConfidencePolicyId policyId,
  SieConfidenceEngineHealth health,
  SieConfidenceEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieConfidenceEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    trackingState:
        status?.trackingState ?? SieTrackingReliabilityState.disabled,
    policyId: status?.policyId ?? ref.watch(sieConfidencePolicyProvider),
    health: status?.health ?? SieConfidenceEngineHealth.idle,
    status: status,
  );
});
