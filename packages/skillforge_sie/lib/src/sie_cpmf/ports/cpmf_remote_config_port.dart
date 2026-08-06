import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';

/// Future-ready remote configuration provider.
abstract interface class CpmfRemoteConfigPort {
  /// Fetch remote overlay (null if unavailable).
  Future<CpmfConfigurationBundle?> fetch();
}

/// No remote config.
final class NopCpmfRemoteConfig implements CpmfRemoteConfigPort {
  /// Creates nop.
  const NopCpmfRemoteConfig();

  @override
  Future<CpmfConfigurationBundle?> fetch() async => null;
}

/// Optional local file / asset loader.
abstract interface class CpmfLocalConfigPort {
  /// Load local overlay.
  Future<CpmfConfigurationBundle?> load();
}

/// No local file.
final class NopCpmfLocalConfig implements CpmfLocalConfigPort {
  /// Creates nop.
  const NopCpmfLocalConfig();

  @override
  Future<CpmfConfigurationBundle?> load() async => null;
}
