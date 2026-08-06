import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_cursor/engine/sie_virtual_cursor_engine.dart';
import 'package:skillforge_sie/src/sie_cursor/logging/sie_cursor_logger.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_engine_status.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/ports/virtual_cursor_engine_port.dart';

/// Active cursor engine config (low frequency).
final sieCursorConfigProvider =
    NotifierProvider<SieCursorConfigNotifier, SieCursorEngineConfig>(
  SieCursorConfigNotifier.new,
);

/// Holds [SieCursorEngineConfig].
final class SieCursorConfigNotifier extends Notifier<SieCursorEngineConfig> {
  @override
  SieCursorEngineConfig build() => const SieCursorEngineConfig();

  /// Replaces config and pushes into the engine.
  void update(SieCursorEngineConfig config) {
    state = config;
    unawaited(ref.read(sieVirtualCursorEngineProvider).setConfig(config));
  }
}

/// Virtual cursor engine (snapshots are not published to Riverpod).
final sieVirtualCursorEngineProvider = Provider<VirtualCursorEnginePort>((ref) {
  final engine = SieVirtualCursorEngine(
    config: ref.read(sieCursorConfigProvider),
    logger: const DeveloperSieCursorLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency status stream.
final sieCursorEngineStatusProvider =
    StreamProvider<SieCursorEngineStatus>((ref) {
  return ref.watch(sieVirtualCursorEngineProvider).status;
});

/// Availability / state / theme / health for host UI (ADR-008).
final sieCursorAvailabilityProvider = Provider<({
  bool initialized,
  bool running,
  bool visible,
  SieCursorState state,
  SieCursorThemeId theme,
  SieCursorMotionProfileId motionProfile,
  SieCursorEngineHealth health,
  SieCursorEngineStatus? status,
})>((ref) {
  final asyncStatus = ref.watch(sieCursorEngineStatusProvider);
  final status = asyncStatus.asData?.value;
  return (
    initialized: status?.initialized ?? false,
    running: status?.running ?? false,
    visible: status?.visible ?? false,
    state: status?.state ?? SieCursorState.hidden,
    theme: status?.theme ?? SieCursorThemeId.standard,
    motionProfile:
        status?.motionProfile ?? SieCursorMotionProfileId.standard,
    health: status?.health ?? SieCursorEngineHealth.idle,
    status: status,
  );
});
