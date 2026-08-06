import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('DefaultPlatformDetector', () {
    test('detect returns a known SiePlatformKind', () {
      const detector = DefaultPlatformDetector();
      final kind = detector.detect();
      expect(SiePlatformKind.values.contains(kind), isTrue);
    });
  });

  group('SiePlatformProfile', () {
    test('web and android are v1 launch targets with streaming', () {
      final web = SiePlatformProfile.forKind(SiePlatformKind.web);
      final android = SiePlatformProfile.forKind(SiePlatformKind.android);
      expect(web.sieSupported, isTrue);
      expect(android.sieSupported, isTrue);
      expect(web.continuousFrameStreamingSupported, isTrue);
      expect(android.continuousFrameStreamingSupported, isTrue);
    });

    test('windows is detected but not SIE-supported in v1', () {
      final win = SiePlatformProfile.forKind(SiePlatformKind.windows);
      expect(win.sieSupported, isFalse);
      expect(win.continuousFrameStreamingSupported, isFalse);
    });
  });

  group('SiePlatformCapabilityService.evaluate', () {
    const envOk = EnvironmentCapabilityFacts(
      secureContext: true,
      mediaDevicesApiAvailable: true,
      cameraPermissionApiAvailable: true,
    );

    test('android with camera devices is runnable', () {
      final caps = SiePlatformCapabilityService.evaluate(
        platform: SiePlatformKind.android,
        profile: SiePlatformProfile.forKind(SiePlatformKind.android),
        env: envOk,
        permission: SiePermissionStatus.granted,
        inventory: const SieCameraInventory(
          probed: true,
          deviceCount: 1,
          hasFrontCamera: true,
          hasBackCamera: false,
        ),
        flags: SieFeatureFlags.defaults(),
      );
      expect(caps.sieRunnable, isTrue);
      expect(caps.unsupportedReason, isNull);
    });

    test('windows fails gracefully with streaming reason', () {
      final caps = SiePlatformCapabilityService.evaluate(
        platform: SiePlatformKind.windows,
        profile: SiePlatformProfile.forKind(SiePlatformKind.windows),
        env: envOk,
        permission: SiePermissionStatus.granted,
        inventory: const SieCameraInventory(
          probed: true,
          deviceCount: 1,
          hasFrontCamera: true,
          hasBackCamera: false,
        ),
        flags: SieFeatureFlags.defaults(),
      );
      expect(caps.sieRunnable, isFalse);
      expect(
        caps.unsupportedReason,
        SieUnsupportedReason.continuousStreamingUnavailable,
      );
      expect(caps.guidanceMessage, isNotNull);
    });

    test('insecure web context is not runnable', () {
      final caps = SiePlatformCapabilityService.evaluate(
        platform: SiePlatformKind.web,
        profile: SiePlatformProfile.forKind(SiePlatformKind.web),
        env: const EnvironmentCapabilityFacts(
          secureContext: false,
          mediaDevicesApiAvailable: true,
          cameraPermissionApiAvailable: false,
        ),
        permission: SiePermissionStatus.unknown,
        inventory: SieCameraInventory.notProbed(),
        flags: SieFeatureFlags.defaults(),
      );
      expect(caps.sieRunnable, isFalse);
      expect(caps.unsupportedReason, SieUnsupportedReason.browserLimitation);
    });

    test('camera feature flag disables runnability', () {
      final flags = SieFeatureFlags.defaults().copyWithOverrides({
        SieFeatureId.camera: false,
      });
      final caps = SiePlatformCapabilityService.evaluate(
        platform: SiePlatformKind.android,
        profile: SiePlatformProfile.forKind(SiePlatformKind.android),
        env: envOk,
        permission: SiePermissionStatus.granted,
        inventory: const SieCameraInventory(
          probed: true,
          deviceCount: 2,
          hasFrontCamera: true,
          hasBackCamera: true,
        ),
        flags: flags,
      );
      expect(caps.sieRunnable, isFalse);
      expect(caps.unsupportedReason, SieUnsupportedReason.featureDisabled);
    });

    test('no camera devices yields noCameraDevice', () {
      final caps = SiePlatformCapabilityService.evaluate(
        platform: SiePlatformKind.web,
        profile: SiePlatformProfile.forKind(SiePlatformKind.web),
        env: envOk,
        permission: SiePermissionStatus.granted,
        inventory: SieCameraInventory.empty(),
        flags: SieFeatureFlags.defaults(),
      );
      expect(caps.sieRunnable, isFalse);
      expect(caps.unsupportedReason, SieUnsupportedReason.noCameraDevice);
    });

    test('permanent denial blocks SIE', () {
      final caps = SiePlatformCapabilityService.evaluate(
        platform: SiePlatformKind.android,
        profile: SiePlatformProfile.forKind(SiePlatformKind.android),
        env: envOk,
        permission: SiePermissionStatus.permanentlyDenied,
        inventory: SieCameraInventory.notProbed(),
        flags: SieFeatureFlags.defaults(),
      );
      expect(caps.sieRunnable, isFalse);
      expect(caps.unsupportedReason, SieUnsupportedReason.permissionBlocked);
    });
  });
}
