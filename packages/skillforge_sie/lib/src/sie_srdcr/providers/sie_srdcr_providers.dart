import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_srdcr/engine/sie_service_registry_composition_root.dart';
import 'package:skillforge_sie/src/sie_srdcr/logging/srdcr_logger.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_registry_snapshot.dart';
import 'package:skillforge_sie/src/sie_srdcr/ports/srdcr_port.dart';

/// Whether SRDCR should use test doubles (fake camera / mock vision).
final sieSrdcrUseTestDoublesProvider = Provider<bool>((ref) => false);

/// Authoritative Service Registry & Dependency Composition Root.
///
/// Riverpod consumes this root — it is not a service locator.
/// Hosts call [SrdcrPort.bootstrap] once at startup.
final sieSrdcrProvider = Provider<SrdcrPort>((ref) {
  final root = SieServiceRegistryCompositionRoot(
    useTestDoubles: ref.watch(sieSrdcrUseTestDoublesProvider),
    logger: const DeveloperSrdcrLogger(),
  );
  ref.onDispose(() {
    unawaited(root.dispose());
  });
  return root;
});

/// Low-frequency status stream (ADR-008).
final sieSrdcrStatusProvider = StreamProvider<SrdcrStatus>((ref) {
  return ref.watch(sieSrdcrProvider).status;
});

/// Riverpod-safe surface only — phase / health / ready (ADR-008).
final sieSrdcrAvailabilityProvider = Provider<({
  SrdcrPhase phase,
  SrdcrHealth health,
  bool ready,
  double startupDurationMs,
  SrdcrStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieSrdcrStatusProvider);
  final status = asyncStatus.asData?.value;
  final root = ref.watch(sieSrdcrProvider);
  final current = status ?? root.currentStatus;
  return (
    phase: current.phase,
    health: current.health,
    ready: current.ready || root.isReady,
    startupDurationMs: current.startupDurationMs,
    status: status,
  );
});
