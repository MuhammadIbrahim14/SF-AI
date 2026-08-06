import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_cpmf/engine/sie_configuration_policy_framework.dart';
import 'package:skillforge_sie/src/sie_cpmf/logging/cpmf_logger.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_snapshot.dart';
import 'package:skillforge_sie/src/sie_cpmf/ports/cpmf_port.dart';
import 'package:skillforge_sie/src/sie_cpmf/ports/cpmf_remote_config_port.dart';
import 'package:skillforge_sie/src/sie_diagnostics/providers/sidf_providers.dart';

/// Remote config override point.
final cpmfRemoteConfigProvider = Provider<CpmfRemoteConfigPort>((ref) {
  return const NopCpmfRemoteConfig();
});

/// Local config override point.
final cpmfLocalConfigProvider = Provider<CpmfLocalConfigPort>((ref) {
  return const NopCpmfLocalConfig();
});

/// CPMF instance.
final sieCpmfProvider = Provider<CpmfPort>((ref) {
  final framework = SieConfigurationPolicyFramework(
    remoteConfig: ref.watch(cpmfRemoteConfigProvider),
    localConfig: ref.watch(cpmfLocalConfigProvider),
    diagnostics: ref.watch(sidfDiagnosticsFrameworkProvider),
    logger: const DeveloperCpmfLogger(),
  );
  ref.onDispose(() {
    unawaited(framework.dispose());
  });
  return framework;
});

/// Low-frequency status stream.
final sieCpmfStatusProvider = StreamProvider<CpmfFrameworkStatus>((ref) {
  return ref.watch(sieCpmfProvider).status;
});

/// Riverpod-safe surface only (ADR-008).
final sieCpmfAvailabilityProvider = Provider<({
  CpmfProfileId activeProfile,
  List<CpmfProfileId> profiles,
  CpmfEnvironment environment,
  String version,
  CpmfHealth health,
  CpmfFrameworkStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieCpmfStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    activeProfile: status?.profileIds.isNotEmpty == true
        ? status!.profileIds.last
        : CpmfProfileId.standard,
    profiles: status?.profileIds ?? const [CpmfProfileId.standard],
    environment: status?.environment ?? CpmfEnvironment.production,
    version: status?.version ?? '0.0.0',
    health: status?.health ?? CpmfHealth.idle,
    status: status,
  );
});
