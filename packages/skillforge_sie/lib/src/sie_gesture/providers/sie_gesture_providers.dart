import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_gesture/engine/sie_gesture_engine.dart';
import 'package:skillforge_sie/src/sie_gesture/logging/sie_gesture_logger.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_engine_status.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';
import 'package:skillforge_sie/src/sie_gesture/ports/gesture_engine_port.dart';

/// Active gesture policy (low frequency).
final sieGesturePolicyProvider =
    NotifierProvider<SieGesturePolicyNotifier, SieGesturePolicy>(
  SieGesturePolicyNotifier.new,
);

/// Holds [SieGesturePolicy].
final class SieGesturePolicyNotifier extends Notifier<SieGesturePolicy> {
  @override
  SieGesturePolicy build() => SieGesturePolicy.standard;

  /// Replaces policy and pushes into the engine.
  void update(SieGesturePolicy policy) {
    state = policy;
    unawaited(ref.read(sieGestureEngineProvider).setPolicy(policy));
  }
}

/// Gesture engine instance (events/snapshots are not published to Riverpod).
final sieGestureEngineProvider = Provider<GestureEnginePort>((ref) {
  final engine = SieGestureEngine(
    policy: ref.read(sieGesturePolicyProvider),
    logger: const DeveloperSieGestureLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieGestureEngineStatusProvider =
    StreamProvider<SieGestureEngineStatus>((ref) {
  return ref.watch(sieGestureEngineProvider).status;
});

/// Availability / activity / policy / health for host UI.
final sieGestureAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SieGestureActivity activity,
  SieGestureKind? primaryKind,
  SieGesturePhase primaryPhase,
  SieGesturePolicyId policyId,
  SieGestureEngineHealth health,
  SieGestureEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieGestureEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    activity: status?.activity ?? SieGestureActivity.none,
    primaryKind: status?.primaryKind,
    primaryPhase: status?.primaryPhase ?? SieGesturePhase.idle,
    policyId: status?.policyId ?? ref.watch(sieGesturePolicyProvider).id,
    health: status?.health ?? SieGestureEngineHealth.idle,
    status: status,
  );
});
