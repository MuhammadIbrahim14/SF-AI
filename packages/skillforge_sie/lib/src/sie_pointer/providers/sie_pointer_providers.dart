import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_pointer/engine/sie_flutter_pointer_bridge.dart';
import 'package:skillforge_sie/src/sie_pointer/logging/sie_pointer_logger.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_bridge_status.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/flutter_pointer_bridge_port.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/pointer_injection_port.dart';

/// Active bridge config (low frequency).
final siePointerBridgeConfigProvider =
    NotifierProvider<SiePointerBridgeConfigNotifier, SiePointerBridgeConfig>(
  SiePointerBridgeConfigNotifier.new,
);

/// Holds [SiePointerBridgeConfig].
final class SiePointerBridgeConfigNotifier
    extends Notifier<SiePointerBridgeConfig> {
  @override
  SiePointerBridgeConfig build() => SiePointerBridgeConfig.standard;

  /// Replaces config.
  void update(SiePointerBridgeConfig config) {
    state = config;
    unawaited(ref.read(sieFlutterPointerBridgeProvider).setConfig(config));
  }
}

/// Injection port override point (host may replace).
final siePointerInjectorProvider = Provider<PointerInjectionPort>((ref) {
  return const NopPointerInjector();
});

/// Pointer bridge instance (events/snapshots not published to Riverpod).
final sieFlutterPointerBridgeProvider =
    Provider<FlutterPointerBridgePort>((ref) {
  final bridge = SieFlutterPointerBridge(
    config: ref.read(siePointerBridgeConfigProvider),
    injector: ref.read(siePointerInjectorProvider),
    logger: const DeveloperSiePointerLogger(),
  );
  ref.onDispose(() {
    unawaited(bridge.dispose());
  });
  return bridge;
});

/// Low-frequency status stream.
final siePointerBridgeStatusProvider =
    StreamProvider<SiePointerBridgeStatus>((ref) {
  return ref.watch(sieFlutterPointerBridgeProvider).status;
});

/// Availability / lifecycle / health for host UI (ADR-008).
final siePointerBridgeAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  SiePointerLifecycleState lifecycle,
  int pointerId,
  bool hovering,
  bool pressed,
  SiePointerBridgeHealth health,
  SiePointerBridgeStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(siePointerBridgeStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    lifecycle: status?.lifecycle ?? SiePointerLifecycleState.absent,
    pointerId: status?.pointerId ?? 0,
    hovering: status?.hovering ?? false,
    pressed: status?.pressed ?? false,
    health: status?.health ?? SiePointerBridgeHealth.idle,
    status: status,
  );
});
