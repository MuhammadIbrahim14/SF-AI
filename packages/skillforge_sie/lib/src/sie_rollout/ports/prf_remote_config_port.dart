import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_device_capability.dart';

/// Future-ready remote configuration port (no concrete remote service required).
abstract interface class PrfRemoteConfigPort {
  /// Fetch remote overlay (null if unavailable).
  Future<PrfConfig?> fetch();
}

/// No remote config.
final class NopPrfRemoteConfig implements PrfRemoteConfigPort {
  /// Creates nop.
  const NopPrfRemoteConfig();

  @override
  Future<PrfConfig?> fetch() async => null;
}

/// Device capability probe (host / platform adapters inject).
abstract interface class PrfDeviceCapabilityProbePort {
  /// Probe current device.
  Future<PrfDeviceCapability> probe(SiePlatformKind platform);
}

/// Static capability for tests / known environments.
final class StaticPrfDeviceCapabilityProbe
    implements PrfDeviceCapabilityProbePort {
  /// Creates probe.
  const StaticPrfDeviceCapabilityProbe(this.capability);

  /// Fixed capability.
  final PrfDeviceCapability capability;

  @override
  Future<PrfDeviceCapability> probe(SiePlatformKind platform) async =>
      capability;
}

/// Conservative default probe (assumes capable when platform is launch target).
final class DefaultPrfDeviceCapabilityProbe
    implements PrfDeviceCapabilityProbePort {
  /// Creates probe.
  const DefaultPrfDeviceCapabilityProbe();

  @override
  Future<PrfDeviceCapability> probe(SiePlatformKind platform) async {
    if (!platform.isV1LaunchTarget &&
        platform != SiePlatformKind.windows &&
        platform != SiePlatformKind.macos) {
      return PrfDeviceCapability.insufficient(platform);
    }
    return PrfDeviceCapability.capable(platform);
  }
}
