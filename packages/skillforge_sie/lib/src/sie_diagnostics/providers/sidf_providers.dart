import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_diagnostics/engine/sidf_diagnostics_framework.dart';
import 'package:skillforge_sie/src/sie_diagnostics/logging/sidf_logger.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_feature_flags.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';

/// SIDF framework instance (per-frame telemetry stays off Riverpod — ADR-008).
final sidfDiagnosticsFrameworkProvider = Provider<SidfDiagnosticsPort>((ref) {
  final framework = SidfDiagnosticsFramework(
    flags: SidfFeatureFlags.forBuildMode(),
    logger: const DeveloperSidfLogger(),
  );
  ref.onDispose(() {
    unawaited(framework.dispose());
  });
  return framework;
});

/// Low-frequency framework status stream.
final sidfFrameworkStatusProvider = StreamProvider<SidfFrameworkStatus>((ref) {
  return ref.watch(sidfDiagnosticsFrameworkProvider).status;
});

/// Riverpod-safe surface: enabled / overlay / recording only.
final sidfAvailabilityProvider = Provider<({
  bool frameworkEnabled,
  bool overlayVisible,
  bool recording,
  SidfFrameworkStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sidfFrameworkStatusProvider);
  final status = asyncStatus.asData?.value;
  final port = ref.watch(sidfDiagnosticsFrameworkProvider);
  return (
    frameworkEnabled: status?.enabled ?? port.flags.frameworkEnabled,
    overlayVisible: status?.overlayVisible ?? false,
    recording: status?.recording ?? false,
    status: status,
  );
});
