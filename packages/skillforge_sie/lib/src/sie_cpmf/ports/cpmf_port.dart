import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// CPMF port — single authoritative configuration source for all SIE engines.
abstract interface class CpmfPort {
  /// Low-frequency status (Riverpod-safe).
  Stream<CpmfFrameworkStatus> get status;

  /// Snapshot stream on significant changes (not Riverpod).
  Stream<CpmfConfigurationSnapshot> get snapshots;

  /// Current status.
  CpmfFrameworkStatus get currentStatus;

  /// Latest immutable snapshot.
  CpmfConfigurationSnapshot get latestSnapshot;

  /// Active bundle (immutable).
  CpmfConfigurationBundle get bundle;

  /// Initialize / load configuration.
  Future<void> initialize({
    required SiePlatformKind platform,
    CpmfEnvironment environment = CpmfEnvironment.production,
    List<CpmfProfileId> profiles = const [CpmfProfileId.standard],
    CpmfConfigurationBundle? buildTime,
    CpmfConfigurationBundle? runtime,
  });

  /// Switch environment.
  Future<void> setEnvironment(CpmfEnvironment environment);

  /// Replace active profile stack (composable).
  Future<void> setProfiles(List<CpmfProfileId> profiles);

  /// Apply runtime overlay.
  Future<void> setRuntimeOverrides(CpmfConfigurationBundle runtime);

  /// Refresh remote / local sources.
  Future<void> refresh();

  /// Evaluate a policy question (deterministic).
  bool evaluatePolicy(
    CpmfPolicyQuestion question, {
    required String routeId,
    required SieSecurityLevel securityLevel,
  });

  /// Domain lookup helpers (constant-time field access on snapshot).
  CpmfConfigurationBundle domainBundle();

  /// Diagnostics for SIDF.
  Map<String, Object?> diagnosticsReport();

  /// Dispose.
  Future<void> dispose();
}
