import 'package:skillforge_sie/src/sie_config/sie_feature_flags.dart';
import 'package:skillforge_sie/src/sie_config/sie_platform_profile.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';

/// Immutable merged configuration snapshot (Document 04 §9).
///
/// Purpose: single read model for session/host — package defaults → app
/// overrides → degraded overlays (future).
/// Inputs: platform kind, flags, optional app overrides already applied.
/// Outputs: profile + flags for capability gating.
/// Failure behavior: construction always succeeds; unsupported platforms use
/// disabled flags via factory helpers.
final class SieConfigSnapshot {
  /// Creates a snapshot.
  const SieConfigSnapshot({
    required this.platform,
    required this.profile,
    required this.featureFlags,
    this.developerMode = false,
  });

  /// Builds defaults for [platform] with optional flag overrides.
  factory SieConfigSnapshot.forPlatform(
    SiePlatformKind platform, {
    SieFeatureFlags? featureFlags,
    bool developerMode = false,
  }) {
    final profile = SiePlatformProfile.forKind(platform);
    final flags = featureFlags ??
        (profile.sieSupported
            ? SieFeatureFlags.defaults()
            : SieFeatureFlags.allDisabled());
    return SieConfigSnapshot(
      platform: platform,
      profile: profile,
      featureFlags: flags,
      developerMode: developerMode,
    );
  }

  /// Active platform kind.
  final SiePlatformKind platform;

  /// Static platform expectations.
  final SiePlatformProfile profile;

  /// Module feature flags.
  final SieFeatureFlags featureFlags;

  /// Host developer mode (may unlock diagnostics overlays when flagged).
  final bool developerMode;

  /// Copy with flag / developer overrides.
  SieConfigSnapshot copyWith({
    SieFeatureFlags? featureFlags,
    bool? developerMode,
  }) {
    return SieConfigSnapshot(
      platform: platform,
      profile: profile,
      featureFlags: featureFlags ?? this.featureFlags,
      developerMode: developerMode ?? this.developerMode,
    );
  }
}
