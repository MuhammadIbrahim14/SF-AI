import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('SieFeatureFlags', () {
    test('defaults enable core features and disable debug overlay', () {
      final flags = SieFeatureFlags.defaults();
      expect(flags.isEnabled(SieFeatureId.camera), isTrue);
      expect(flags.isEnabled(SieFeatureId.handTracking), isTrue);
      expect(flags.isEnabled(SieFeatureId.cursor), isTrue);
      expect(flags.isEnabled(SieFeatureId.gestures), isTrue);
      expect(flags.isEnabled(SieFeatureId.diagnostics), isTrue);
      expect(flags.isEnabled(SieFeatureId.debugOverlay), isFalse);
    });

    test('copyWithOverrides is independent of engine logic', () {
      final flags = SieFeatureFlags.defaults().copyWithOverrides({
        SieFeatureId.gestures: false,
        SieFeatureId.debugOverlay: true,
      });
      expect(flags.isEnabled(SieFeatureId.gestures), isFalse);
      expect(flags.isEnabled(SieFeatureId.debugOverlay), isTrue);
      expect(flags.isEnabled(SieFeatureId.camera), isTrue);
    });

    test('allDisabled clears every feature', () {
      final flags = SieFeatureFlags.allDisabled();
      for (final id in SieFeatureId.values) {
        expect(flags.isEnabled(id), isFalse, reason: id.name);
      }
    });
  });

  group('SieFeatureFlagService', () {
    test('setEnabled updates snapshot', () {
      final service = SieFeatureFlagService();
      service.setEnabled(SieFeatureId.debugOverlay, enabled: true);
      expect(service.isEnabled(SieFeatureId.debugOverlay), isTrue);
      service.disableAll();
      expect(service.isEnabled(SieFeatureId.camera), isFalse);
      service.resetToDefaults();
      expect(service.isEnabled(SieFeatureId.camera), isTrue);
    });
  });

  group('SieConfigSnapshot', () {
    test('unsupported platform uses disabled flags by default', () {
      final snap = SieConfigSnapshot.forPlatform(SiePlatformKind.windows);
      expect(snap.profile.sieSupported, isFalse);
      expect(snap.featureFlags.isEnabled(SieFeatureId.camera), isFalse);
    });

    test('web platform keeps default flags', () {
      final snap = SieConfigSnapshot.forPlatform(SiePlatformKind.web);
      expect(snap.profile.sieSupported, isTrue);
      expect(snap.featureFlags.isEnabled(SieFeatureId.cursor), isTrue);
    });
  });
}
