import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_camera/adapters/camera_adapter_factory.dart';
import 'package:skillforge_sie/src/sie_camera/engine/sie_camera_engine.dart';
import 'package:skillforge_sie/src/sie_camera/logging/sie_camera_logger.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_status.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_platform_adapter_port.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_port.dart';
import 'package:skillforge_sie/src/sie_platform/providers/sie_platform_providers.dart';

/// Overrideable platform camera adapter.
final sieCameraPlatformAdapterProvider = Provider<CameraPlatformAdapterPort>(
  (ref) => createDefaultCameraPlatformAdapter(
    platform: ref.watch(siePlatformKindProvider),
  ),
);

/// Camera capture configuration (low frequency).
final sieCameraConfigProvider =
    NotifierProvider<SieCameraConfigNotifier, SieCameraConfig>(
  SieCameraConfigNotifier.new,
);

/// Holds [SieCameraConfig].
final class SieCameraConfigNotifier extends Notifier<SieCameraConfig> {
  @override
  SieCameraConfig build() => SieCameraConfig.sieDefaults;

  /// Replaces config.
  // ignore: use_setters_to_change_properties
  void update(SieCameraConfig config) => state = config;
}

/// Singleton-ish engine for the container lifetime.
final sieCameraEngineProvider = Provider<CameraPort>((ref) {
  final engine = SieCameraEngine(
    adapter: ref.watch(sieCameraPlatformAdapterProvider),
    permissionPort: ref.watch(sieCameraPermissionPortProvider),
    config: ref.watch(sieCameraConfigProvider),
    logger: const DeveloperSieCameraLogger(),
  );
  ref.onDispose(() {
    unawaited(engine.dispose());
  });
  return engine;
});

/// Low-frequency camera status for UI (not frames — ADR-008).
final sieCameraStatusProvider =
    StreamProvider<SieCameraStatus>((ref) {
  final engine = ref.watch(sieCameraEngineProvider);
  return engine.status;
});

/// Selected camera device from latest status.
final sieSelectedCameraProvider = Provider<SieCameraDeviceInfo?>((ref) {
  return ref.watch(sieCameraStatusProvider).asData?.value.selected;
});

/// Available cameras from latest status (may be empty until discover).
final sieAvailableCamerasProvider = Provider<List<SieCameraDeviceInfo>>((ref) {
  return ref.watch(sieCameraStatusProvider).asData?.value.available ?? const [];
});
