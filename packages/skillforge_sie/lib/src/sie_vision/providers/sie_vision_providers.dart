import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_vision/adapters/hand_landmarker_backend_factory.dart';
import 'package:skillforge_sie/src/sie_vision/engine/sie_vision_provider.dart';
import 'package:skillforge_sie/src/sie_vision/logging/sie_vision_logger.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_config.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_enums.dart';
import 'package:skillforge_sie/src/sie_vision/models/sie_vision_status.dart';
import 'package:skillforge_sie/src/sie_vision/ports/hand_landmarker_backend_port.dart';
import 'package:skillforge_sie/src/sie_vision/ports/vision_runtime_port.dart';
import 'package:skillforge_sie/src/sie_platform/providers/sie_platform_providers.dart';

/// Overrideable Hand Landmarker backend (MediaPipe / mock / unsupported).
final sieHandLandmarkerBackendProvider = Provider<HandLandmarkerBackendPort>(
  (ref) => createDefaultHandLandmarkerBackend(
    platform: ref.watch(siePlatformKindProvider),
  ),
);

/// Vision config (low frequency).
final sieVisionConfigProvider =
    NotifierProvider<SieVisionConfigNotifier, SieVisionConfig>(
  SieVisionConfigNotifier.new,
);

/// Holds [SieVisionConfig].
final class SieVisionConfigNotifier extends Notifier<SieVisionConfig> {
  @override
  SieVisionConfig build() => SieVisionConfig.sieDefaults;

  /// Replaces config.
  // ignore: use_setters_to_change_properties
  void update(SieVisionConfig config) => state = config;
}

/// Vision runtime (does not publish landmarks to Riverpod).
final sieVisionRuntimeProvider = Provider<VisionRuntimePort>((ref) {
  final runtime = SieVisionProvider(
    backend: ref.watch(sieHandLandmarkerBackendProvider),
    config: ref.watch(sieVisionConfigProvider),
    logger: const DeveloperSieVisionLogger(),
  );
  ref.onDispose(() {
    unawaited(runtime.dispose());
  });
  return runtime;
});

/// Low-frequency vision status stream.
final sieVisionStatusProvider = StreamProvider<SieVisionStatus>((ref) {
  return ref.watch(sieVisionRuntimeProvider).status;
});

/// Whether the vision backend is available / initialized.
final sieVisionAvailabilityProvider = Provider<({
  bool supported,
  bool initialized,
  SieVisionBackendKind backend,
})>((ref) {
  final status = ref.watch(sieVisionStatusProvider).asData?.value;
  final backend = ref.watch(sieHandLandmarkerBackendProvider);
  return (
    supported: backend.isSupported,
    initialized: status?.initialized ?? false,
    backend: backend.kind,
  );
});
