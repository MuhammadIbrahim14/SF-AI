import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/src/sie_config/sie_config_snapshot.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_flags.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_id.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/default_platform_detector.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/flutter_camera_inventory.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/flutter_camera_permission_adapter.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/flutter_capability_probe.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_permission_snapshot.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_platform_capabilities.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_inventory_port.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_permission_port.dart';
import 'package:skillforge_sie/src/sie_platform/ports/capability_probe_port.dart';
import 'package:skillforge_sie/src/sie_platform/ports/platform_detector_port.dart';
import 'package:skillforge_sie/src/sie_platform/services/sie_feature_flag_service.dart';
import 'package:skillforge_sie/src/sie_platform/services/sie_permission_manager.dart';
import 'package:skillforge_sie/src/sie_platform/services/sie_platform_capability_service.dart';

// ---------------------------------------------------------------------------
// DI overrides — host / tests replace these. Low-frequency only (ADR-008).
// ---------------------------------------------------------------------------

/// Platform detector port.
final siePlatformDetectorProvider = Provider<PlatformDetectorPort>(
  (ref) => const DefaultPlatformDetector(),
);

/// Environment capability probe port.
final sieCapabilityProbeProvider = Provider<CapabilityProbePort>(
  (ref) => const FlutterCapabilityProbe(),
);

/// Camera permission port.
final sieCameraPermissionPortProvider = Provider<CameraPermissionPort>(
  (ref) => const FlutterCameraPermissionAdapter(),
);

/// Camera inventory port (enumeration only).
final sieCameraInventoryPortProvider = Provider<CameraInventoryPort>(
  (ref) => const FlutterCameraInventory(),
);

/// Feature flag service (session-scoped configuration).
final sieFeatureFlagServiceProvider =
    NotifierProvider<SieFeatureFlagNotifier, SieFeatureFlags>(
  SieFeatureFlagNotifier.new,
);

/// Permission manager façade.
final siePermissionManagerProvider = Provider<SiePermissionManager>((ref) {
  return SiePermissionManager(
    permissionPort: ref.watch(sieCameraPermissionPortProvider),
  );
});

/// Capability orchestration service.
final siePlatformCapabilityServiceProvider =
    Provider<SiePlatformCapabilityService>((ref) {
  final flags = ref.watch(sieFeatureFlagServiceProvider);
  return SiePlatformCapabilityService(
    detector: ref.watch(siePlatformDetectorProvider),
    capabilityProbe: ref.watch(sieCapabilityProbeProvider),
    permissionPort: ref.watch(sieCameraPermissionPortProvider),
    cameraInventory: ref.watch(sieCameraInventoryPortProvider),
    featureFlags: flags,
  );
});

/// Sync platform kind (no I/O).
final siePlatformKindProvider = Provider<SiePlatformKind>((ref) {
  return ref.watch(siePlatformDetectorProvider).detect();
});

/// Config snapshot derived from platform + flags.
final sieConfigSnapshotProvider = Provider<SieConfigSnapshot>((ref) {
  final platform = ref.watch(siePlatformKindProvider);
  final flags = ref.watch(sieFeatureFlagServiceProvider);
  return SieConfigSnapshot.forPlatform(platform, featureFlags: flags);
});

/// Async capability probe result.
///
/// Re-run with `ref.invalidate(siePlatformCapabilitiesProvider)`.
final siePlatformCapabilitiesProvider =
    FutureProvider<SiePlatformCapabilities>((ref) async {
  final service = ref.watch(siePlatformCapabilityServiceProvider);
  return service.probe();
});

/// Permission snapshot notifier (request / refresh).
final siePermissionStateProvider =
    AsyncNotifierProvider<SiePermissionNotifier, SiePermissionSnapshot>(
  SiePermissionNotifier.new,
);

/// Holds [SieFeatureFlags] in Riverpod.
final class SieFeatureFlagNotifier extends Notifier<SieFeatureFlags> {
  late final SieFeatureFlagService _service;

  @override
  SieFeatureFlags build() {
    _service = SieFeatureFlagService();
    return _service.flags;
  }

  /// Enables or disables [id].
  void setEnabled(SieFeatureId id, {required bool enabled}) {
    _service.setEnabled(id, enabled: enabled);
    state = _service.flags;
  }

  /// Applies multiple overrides.
  void applyOverrides(Map<SieFeatureId, bool> overrides) {
    _service.applyOverrides(overrides);
    state = _service.flags;
  }

  /// Resets to defaults.
  void resetToDefaults() {
    _service.resetToDefaults();
    state = _service.flags;
  }

  /// Kill-switch helper.
  void disableAll() {
    _service.disableAll();
    state = _service.flags;
  }
}

/// Async permission state for host UI.
final class SiePermissionNotifier
    extends AsyncNotifier<SiePermissionSnapshot> {
  @override
  Future<SiePermissionSnapshot> build() {
    return ref.read(siePermissionManagerProvider).refresh();
  }

  /// Requests camera permission (IDS opt-in).
  Future<SiePermissionSnapshot> request() async {
    state = const AsyncLoading();
    final next =
        await ref.read(siePermissionManagerProvider).requestCameraPermission();
    state = AsyncData(next);
    return next;
  }

  /// Re-checks without prompting.
  Future<SiePermissionSnapshot> refresh() async {
    final next = await ref.read(siePermissionManagerProvider).refresh();
    state = AsyncData(next);
    return next;
  }

  /// Opens settings when permanently denied.
  Future<bool> openSettings() {
    return ref.read(siePermissionManagerProvider).openPermissionSettings();
  }
}
