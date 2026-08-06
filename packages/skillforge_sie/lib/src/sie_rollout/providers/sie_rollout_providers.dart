import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_diagnostics/providers/sidf_providers.dart';
import 'package:skillforge_sie/src/sie_integration/providers/sie_integration_providers.dart';
import 'package:skillforge_sie/src/sie_rollout/engine/sie_progressive_rollout_framework.dart';
import 'package:skillforge_sie/src/sie_rollout/logging/prf_logger.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_snapshot.dart';
import 'package:skillforge_sie/src/sie_rollout/ports/prf_remote_config_port.dart';
import 'package:skillforge_sie/src/sie_rollout/ports/progressive_rollout_port.dart';

/// Optional remote config override (future Firebase / LaunchDarkly, etc.).
final prfRemoteConfigProvider = Provider<PrfRemoteConfigPort>((ref) {
  return const NopPrfRemoteConfig();
});

/// Optional device probe override.
final prfDeviceProbeProvider = Provider<PrfDeviceCapabilityProbePort>((ref) {
  return const DefaultPrfDeviceCapabilityProbe();
});

/// Progressive Rollout Framework (wires Integration + SIDF).
final sieProgressiveRolloutProvider = Provider<ProgressiveRolloutPort>((ref) {
  final framework = SieProgressiveRolloutFramework(
    integration: ref.watch(sieIntegrationFrameworkProvider),
    diagnostics: ref.watch(sidfDiagnosticsFrameworkProvider),
    remoteConfig: ref.watch(prfRemoteConfigProvider),
    deviceProbe: ref.watch(prfDeviceProbeProvider),
    logger: const DeveloperPrfLogger(),
  );
  ref.onDispose(() {
    unawaited(framework.dispose());
  });
  return framework;
});

/// Low-frequency status stream.
final sieRolloutStatusProvider = StreamProvider<PrfRolloutStatus>((ref) {
  return ref.watch(sieProgressiveRolloutProvider).status;
});

/// Riverpod-safe surface only (ADR-008).
final sieRolloutAvailabilityProvider = Provider<({
  bool sieEnabled,
  PrfCanaryPhase canaryPhase,
  SiePlatformKind platform,
  bool platformAllowed,
  PrfFeatureFlags flags,
  PrfHealth health,
  bool killSwitchActive,
  PrfRolloutStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieRolloutStatusProvider);
  final status = asyncStatus.asData?.value;
  final port = ref.watch(sieProgressiveRolloutProvider);
  return (
    sieEnabled: status?.sieEnabled ?? port.sieEnabled,
    canaryPhase: status?.canaryPhase ?? PrfCanaryPhase.off,
    platform: status?.platform ?? SiePlatformKind.unsupported,
    platformAllowed: status?.platformAllowed ?? false,
    flags: status?.flags ?? port.config.flags,
    health: status?.health ?? PrfHealth.idle,
    killSwitchActive: status?.killSwitchActive ?? false,
    status: status,
  );
});
