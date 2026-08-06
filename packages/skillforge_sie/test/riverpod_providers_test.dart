import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

class _FixedDetector implements PlatformDetectorPort {
  _FixedDetector(this.kind);
  final SiePlatformKind kind;
  @override
  SiePlatformKind detect() => kind;
}

class _FixedProbe implements CapabilityProbePort {
  @override
  Future<EnvironmentCapabilityFacts> probe() async =>
      const EnvironmentCapabilityFacts(
        secureContext: true,
        mediaDevicesApiAvailable: true,
        cameraPermissionApiAvailable: true,
      );
}

class _GrantedPermission implements CameraPermissionPort {
  @override
  Future<SiePermissionStatus> check() async => SiePermissionStatus.granted;

  @override
  Future<SiePermissionStatus> request() async => SiePermissionStatus.granted;

  @override
  Future<bool> openSettings() async => false;
}

class _OneCameraInventory implements CameraInventoryPort {
  @override
  Future<SieCameraInventory> probe() async => const SieCameraInventory(
        probed: true,
        deviceCount: 1,
        hasFrontCamera: true,
        hasBackCamera: false,
      );
}

void main() {
  test('Riverpod capability provider uses overridden ports', () async {
    final container = ProviderContainer(
      overrides: [
        siePlatformDetectorProvider.overrideWithValue(
          _FixedDetector(SiePlatformKind.android),
        ),
        sieCapabilityProbeProvider.overrideWithValue(_FixedProbe()),
        sieCameraPermissionPortProvider.overrideWithValue(_GrantedPermission()),
        sieCameraInventoryPortProvider.overrideWithValue(_OneCameraInventory()),
      ],
    );
    addTearDown(container.dispose);

    final caps = await container.read(siePlatformCapabilitiesProvider.future);
    expect(caps.platform, SiePlatformKind.android);
    expect(caps.sieRunnable, isTrue);

    final kind = container.read(siePlatformKindProvider);
    expect(kind, SiePlatformKind.android);

    container
        .read(sieFeatureFlagServiceProvider.notifier)
        .setEnabled(SieFeatureId.camera, enabled: false);

    // Service is rebuilt with new flags; invalidate capability probe.
    container.invalidate(siePlatformCapabilitiesProvider);
    final caps2 = await container.read(siePlatformCapabilitiesProvider.future);
    expect(caps2.sieRunnable, isFalse);
  });

  test('feature flag notifier exposes defaults', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final flags = container.read(sieFeatureFlagServiceProvider);
    expect(flags.isEnabled(SieFeatureId.debugOverlay), isFalse);
  });
}
